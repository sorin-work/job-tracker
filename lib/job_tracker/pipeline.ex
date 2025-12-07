defmodule JobTracker.Pipeline do
  @moduledoc """
  Job applications and the status history that is recorded as they move
  through the pipeline.

  Every function takes the current user and only ever touches that user's data.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias JobTracker.Accounts.User
  alias JobTracker.Companies
  alias JobTracker.Pipeline.{JobApplication, Status, StatusChange}
  alias JobTracker.Repo

  ## Listing

  @doc """
  Lists applications with their company.

  ## Options

    * `:company_id` - only applications for this company
  """
  def list_applications(%User{} = user, opts \\ []) do
    user
    |> base_query(opts)
    |> order_by([a], desc: a.updated_at, desc: a.id)
    |> Repo.all()
    |> Repo.preload(:company)
  end

  defp base_query(user, opts) do
    from(a in JobApplication, as: :application, where: a.user_id == ^user.id)
    |> filter_company(opts[:company_id])
  end

  defp filter_company(query, nil), do: query
  defp filter_company(query, company_id), do: where(query, [a], a.company_id == ^company_id)

  @doc """
  Applications grouped by status for the board, each column ordered by its
  position.
  """
  def board(%User{} = user) do
    applications =
      Repo.all(
        from a in JobApplication,
          where: a.user_id == ^user.id,
          order_by: [asc: a.position],
          preload: [:company]
      )

    grouped = Enum.group_by(applications, & &1.status)
    Map.new(Status.all(), &{&1, Map.get(grouped, &1, [])})
  end

  ## Single applications

  @doc """
  Gets one of the user's applications with everything the detail page shows.
  """
  def get_application!(%User{} = user, id) do
    JobApplication
    |> Repo.get_by!(id: id, user_id: user.id)
    |> Repo.preload([
      :company,
      :status_changes
    ])
  end

  def change_application(%JobApplication{} = application, attrs \\ %{}) do
    JobApplication.changeset(application, attrs)
  end

  @doc """
  Creates an application and records its first status in the history.

  The company can be given as `company_id` or as a `company_name`, which is
  looked up (case-insensitively) or created.
  """
  def create_application(%User{} = user, attrs) do
    now = DateTime.utc_now(:second)
    changeset = JobApplication.changeset(%JobApplication{user_id: user.id}, attrs)

    if changeset.valid?,
      do: insert_application(user, changeset, now),
      else: {:error, %{changeset | action: :insert}}
  end

  defp insert_application(user, changeset, now) do
    Multi.new()
    |> Multi.run(:company, fn _repo, _ -> resolve_company(user, changeset) end)
    |> Multi.insert(:application, fn %{company: company} ->
      status = Ecto.Changeset.get_field(changeset, :status)

      changeset
      |> Ecto.Changeset.put_change(:company_id, company.id)
      |> Ecto.Changeset.put_change(:position, next_position(user, status))
      |> maybe_set_applied_on(user, status)
    end)
    |> Multi.insert(:status_change, fn %{application: application} ->
      %StatusChange{
        job_application_id: application.id,
        to_status: application.status,
        changed_at: now
      }
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{application: application}} -> {:ok, Repo.preload(application, :company)}
      {:error, :company, _company_changeset, _} -> {:error, company_error(changeset)}
      {:error, _step, %Ecto.Changeset{} = error, _} -> {:error, merge_errors(changeset, error)}
    end
  end

  @doc """
  Updates an application. A status change is recorded in the history.
  """
  def update_application(%User{} = user, %JobApplication{} = application, attrs) do
    changeset = JobApplication.changeset(application, attrs)

    if changeset.valid?,
      do: save_application(user, application, changeset),
      else: {:error, %{changeset | action: :update}}
  end

  defp save_application(user, application, changeset) do
    Multi.new()
    |> Multi.run(:company, fn _repo, _ -> resolve_company(user, changeset) end)
    |> Multi.update(:application, fn %{company: company} ->
      status = Ecto.Changeset.get_field(changeset, :status)

      changeset
      |> Ecto.Changeset.put_change(:company_id, company.id)
      |> maybe_set_applied_on(user, status)
    end)
    |> record_status_change(user, application)
    |> Repo.transaction()
    |> case do
      {:ok, %{application: application}} ->
        {:ok, Repo.preload(application, :company, force: true)}

      {:error, :company, _company_changeset, _} ->
        {:error, company_error(changeset)}

      {:error, _step, %Ecto.Changeset{} = error, _} ->
        {:error, merge_errors(changeset, error)}
    end
  end

  @doc """
  Moves an application to a new status, optionally with a note for the
  timeline. Moving to the current status is a no-op.
  """
  def change_status(%User{} = user, %JobApplication{} = application, status, note \\ nil) do
    status = Status.cast!(status)

    if status == application.status do
      {:ok, application}
    else
      changeset =
        application
        |> Ecto.Changeset.change(status: status, position: next_position(user, status))
        |> maybe_set_applied_on(user, status)

      Multi.new()
      |> Multi.update(:application, changeset)
      |> record_status_change(user, application, note)
      |> Repo.transaction()
      |> case do
        {:ok, %{application: application}} -> {:ok, application}
        {:error, _step, error, _} -> {:error, error}
      end
    end
  end

  @doc """
  Moves an application on the board: into the column for `status`, at `index`
  within that column. The other cards in the column are renumbered.
  """
  def move_application(%User{} = user, id, status, index) do
    with {:ok, status} <- Status.cast(status),
         %JobApplication{} = application <- Repo.get_by(JobApplication, id: id, user_id: user.id) do
      siblings =
        Repo.all(
          from a in JobApplication,
            where: a.user_id == ^user.id and a.status == ^status and a.id != ^application.id,
            order_by: [asc: a.position, desc: a.updated_at],
            select: a.id
        )

      ordered = List.insert_at(siblings, index, application.id)

      changeset = JobApplication.move_changeset(application, status, index)

      Multi.new()
      |> Multi.update(:application, changeset)
      |> Multi.run(:positions, fn repo, _ -> renumber(repo, ordered) end)
      |> record_status_change(user, application)
      |> Repo.transaction()
      |> case do
        {:ok, %{application: application}} -> {:ok, application}
        {:error, _step, error, _} -> {:error, error}
      end
    else
      :error -> {:error, :invalid_status}
      nil -> {:error, :not_found}
    end
  end

  defp renumber(repo, ids) do
    ids
    |> Enum.with_index()
    |> Enum.each(fn {id, position} ->
      repo.update_all(from(a in JobApplication, where: a.id == ^id), set: [position: position])
    end)

    {:ok, length(ids)}
  end

  def delete_application(%JobApplication{} = application) do
    Repo.delete(application)
  end

  defp record_status_change(multi, _user, previous, note \\ nil) do
    multi
    |> Multi.run(:status_change, fn repo, %{application: application} ->
      if application.status == previous.status do
        {:ok, nil}
      else
        repo.insert(%StatusChange{
          job_application_id: application.id,
          from_status: previous.status,
          to_status: application.status,
          note: note,
          changed_at: DateTime.utc_now(:second)
        })
      end
    end)
  end

  defp next_position(user, status) do
    Repo.one(
      from a in JobApplication,
        where: a.user_id == ^user.id and a.status == ^status,
        select: coalesce(max(a.position) + 1, 0)
    )
  end

  # The application date is filled in the first time it moves past the wishlist.
  defp maybe_set_applied_on(changeset, _user, status) do
    rank = Status.rank(status)

    if rank && rank >= 1 && is_nil(Ecto.Changeset.get_field(changeset, :applied_on)) do
      Ecto.Changeset.put_change(changeset, :applied_on, Date.utc_today())
    else
      changeset
    end
  end

  defp resolve_company(user, changeset) do
    case Ecto.Changeset.get_change(changeset, :company_name) do
      name when is_binary(name) ->
        Companies.find_or_create_company(user, name)

      nil ->
        case Ecto.Changeset.get_field(changeset, :company_id) do
          nil -> {:error, :missing_company}
          id -> fetch_company(user, id)
        end
    end
  end

  defp fetch_company(user, id) do
    case Repo.get_by(JobTracker.Companies.Company, id: id, user_id: user.id) do
      nil -> {:error, :missing_company}
      company -> {:ok, company}
    end
  end

  defp company_error(changeset) do
    field =
      if Ecto.Changeset.get_change(changeset, :company_name), do: :company_name, else: :company_id

    changeset
    |> Ecto.Changeset.add_error(field, "is not valid")
    |> Map.put(:action, :validate)
  end

  # Errors from the insert or update steps come back on the changeset that was
  # built inside the multi. The form keeps showing the original changeset (with
  # the virtual fields the user typed), so copy the errors over.
  defp merge_errors(changeset, %Ecto.Changeset{errors: errors}) do
    %{changeset | errors: Enum.uniq(changeset.errors ++ errors), valid?: false, action: :validate}
  end

  ## Timeline

  @doc """
  The events shown on an application's timeline, newest first. Expects the
  application to come from `get_application!/2`.
  """
  def timeline(%JobApplication{status_changes: changes}) do
    status_events =
      Enum.map(changes, fn change ->
        %{
          type: :status,
          at: change.changed_at,
          from: change.from_status,
          to: change.to_status,
          note: change.note
        }
      end)

    Enum.sort_by(status_events, & &1.at, {:desc, DateTime})
  end
end
