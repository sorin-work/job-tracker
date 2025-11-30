defmodule JobTracker.Pipeline do
  @moduledoc """
  Job applications and where they are in the pipeline.

  Every function takes the current user and only ever touches that user's data.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias JobTracker.Accounts.User
  alias JobTracker.Companies
  alias JobTracker.Pipeline.{JobApplication, Status}
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

  ## Single applications

  @doc """
  Gets one of the user's applications with everything the detail page shows.
  """
  def get_application!(%User{} = user, id) do
    JobApplication
    |> Repo.get_by!(id: id, user_id: user.id)
    |> Repo.preload(:company)
  end

  def change_application(%JobApplication{} = application, attrs \\ %{}) do
    JobApplication.changeset(application, attrs)
  end

  @doc """
  Creates an application.

  The company can be given as `company_id` or as a `company_name`, which is
  looked up (case-insensitively) or created.
  """
  def create_application(%User{} = user, attrs) do
    changeset = JobApplication.changeset(%JobApplication{user_id: user.id}, attrs)

    if changeset.valid?,
      do: insert_application(user, changeset),
      else: {:error, %{changeset | action: :insert}}
  end

  defp insert_application(user, changeset) do
    Multi.new()
    |> Multi.run(:company, fn _repo, _ -> resolve_company(user, changeset) end)
    |> Multi.insert(:application, fn %{company: company} ->
      status = Ecto.Changeset.get_field(changeset, :status)

      changeset
      |> Ecto.Changeset.put_change(:company_id, company.id)
      |> maybe_set_applied_on(user, status)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{application: application}} -> {:ok, Repo.preload(application, :company)}
      {:error, :company, _company_changeset, _} -> {:error, company_error(changeset)}
      {:error, _step, %Ecto.Changeset{} = error, _} -> {:error, merge_errors(changeset, error)}
    end
  end

  @doc """
  Updates an application.
  """
  def update_application(%User{} = user, %JobApplication{} = application, attrs) do
    changeset = JobApplication.changeset(application, attrs)

    if changeset.valid?,
      do: save_application(user, application, changeset),
      else: {:error, %{changeset | action: :update}}
  end

  defp save_application(user, _application, changeset) do
    Multi.new()
    |> Multi.run(:company, fn _repo, _ -> resolve_company(user, changeset) end)
    |> Multi.update(:application, fn %{company: company} ->
      status = Ecto.Changeset.get_field(changeset, :status)

      changeset
      |> Ecto.Changeset.put_change(:company_id, company.id)
      |> maybe_set_applied_on(user, status)
    end)
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

  def delete_application(%JobApplication{} = application) do
    Repo.delete(application)
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
end
