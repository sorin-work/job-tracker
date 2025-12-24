defmodule JobTracker.Pipeline do
  @moduledoc """
  Job applications, the status history that is recorded as they move through
  the pipeline, and the tags used to group them.

  Every function takes the current user and only ever touches that user's data.
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias JobTracker.Accounts.User
  alias JobTracker.Companies
  alias JobTracker.Pipeline.{JobApplication, Status, StatusChange, Tag}
  alias JobTracker.Repo

  @per_page 25
  @sortable ~w(updated applied company title status salary priority)

  ## Listing

  @doc """
  Lists applications with their company and tags.

  ## Options

    * `:status` - a status or a list of statuses
    * `:company_id` - only applications for this company
    * `:tag_id` - only applications with this tag
    * `:search` - text to look for in the title and company name
  """
  def list_applications(%User{} = user, opts \\ []) do
    user
    |> base_query(opts)
    |> order_by([a], desc: a.updated_at, desc: a.id)
    |> Repo.all()
    |> Repo.preload([:company, :tags])
  end

  @doc """
  Filters, sorts and paginates applications for the table view.

  Takes the query params as they come from the URL and returns a map with the
  `:entries` for the page plus `:page`, `:per_page`, `:total` and
  `:total_pages`. Unknown or invalid params fall back to the defaults.
  """
  def search_applications(%User{} = user, params \\ %{}) do
    opts = [
      status: parse_status(params["status"]),
      tag_id: parse_id(params["tag"]),
      company_id: parse_id(params["company"]),
      search: params["q"]
    ]

    query = base_query(user, opts)
    total = Repo.aggregate(query, :count)
    total_pages = max(div(total + @per_page - 1, @per_page), 1)
    page = params["page"] |> parse_id() |> Kernel.||(1)

    entries =
      query
      |> sort(params["sort"], params["dir"])
      |> limit(^@per_page)
      |> offset(^((page - 1) * @per_page))
      |> Repo.all()
      |> Repo.preload([:company, :tags])

    %{entries: entries, page: page, per_page: @per_page, total: total, total_pages: total_pages}
  end

  def sortable_fields, do: @sortable

  defp base_query(user, opts) do
    from(a in JobApplication, as: :application, where: a.user_id == ^user.id)
    |> filter_status(opts[:status])
    |> filter_company(opts[:company_id])
    |> filter_tag(opts[:tag_id])
    |> filter_search(opts[:search])
  end

  defp filter_status(query, nil), do: query

  defp filter_status(query, statuses) when is_list(statuses),
    do: where(query, [a], a.status in ^statuses)

  defp filter_status(query, status), do: where(query, [a], a.status == ^status)

  defp filter_company(query, nil), do: query
  defp filter_company(query, company_id), do: where(query, [a], a.company_id == ^company_id)

  defp filter_tag(query, nil), do: query

  defp filter_tag(query, tag_id) do
    where(
      query,
      [a],
      exists(
        from t in "job_application_tags",
          where: t.job_application_id == parent_as(:application).id and t.tag_id == ^tag_id,
          select: 1
      )
    )
  end

  defp filter_search(query, search) when is_binary(search) do
    case search do
      "" ->
        query

      text ->
        pattern = "%" <> Companies.escape_like(text) <> "%"

        query
        |> join_company()
        |> where([a, company: c], ilike(a.title, ^pattern) or ilike(c.name, ^pattern))
    end
  end

  defp filter_search(query, _search), do: query

  defp join_company(query) do
    if has_named_binding?(query, :company) do
      query
    else
      join(query, :inner, [a], c in assoc(a, :company), as: :company)
    end
  end

  defp sort(query, field, dir) do
    field = if field in @sortable, do: field, else: "updated"
    dir = if dir == "asc", do: :asc, else: :desc
    nulls_last = if dir == :asc, do: :asc_nulls_last, else: :desc_nulls_last

    sort_by(query, field, dir, nulls_last)
  end

  defp sort_by(query, "updated", dir, _nulls_last),
    do: order_by(query, [a], [{^dir, a.updated_at}, {^dir, a.id}])

  defp sort_by(query, "applied", dir, nulls_last),
    do: order_by(query, [a], [{^nulls_last, a.applied_on}, {^dir, a.id}])

  defp sort_by(query, "title", dir, _nulls_last),
    do: order_by(query, [a], [{^dir, fragment("lower(?)", a.title)}, {^dir, a.id}])

  defp sort_by(query, "company", dir, _nulls_last) do
    query
    |> join_company()
    |> order_by([a, company: c], [{^dir, fragment("lower(?)", c.name)}, {^dir, a.id}])
  end

  defp sort_by(query, "status", dir, _nulls_last),
    do: order_by(query, ^[{dir, status_order_fragment()}, {dir, dynamic([a], a.id)}])

  defp sort_by(query, "salary", dir, nulls_last),
    do: order_by(query, [a], [{^nulls_last, coalesce(a.salary_max, a.salary_min)}, {^dir, a.id}])

  defp sort_by(query, "priority", dir, _nulls_last),
    do: order_by(query, [a], [{^dir, a.priority}, {^dir, a.id}])

  defp status_order_fragment do
    statuses = Enum.map(Status.all(), &Atom.to_string/1)
    dynamic([a], fragment("array_position(?::varchar[], ?)", ^statuses, a.status))
  end

  defp parse_status(nil), do: nil
  defp parse_status(""), do: nil
  defp parse_status("open"), do: Status.open()
  defp parse_status("closed"), do: Status.closed()

  defp parse_status(value) do
    case Status.cast(value) do
      {:ok, status} -> status
      :error -> nil
    end
  end

  defp parse_id(value) when is_integer(value) and value > 0, do: value

  defp parse_id(value) when is_binary(value) do
    case Integer.parse(value) do
      {id, ""} when id > 0 -> id
      _ -> nil
    end
  end

  defp parse_id(_value), do: nil

  @doc """
  Applications grouped by status for the board, each column ordered by its
  position.
  """
  def board(%User{} = user) do
    applications =
      Repo.all(
        from a in JobApplication,
          where: a.user_id == ^user.id,
          order_by: [asc: a.position, desc: a.updated_at],
          preload: [:company, :tags]
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
      :tags,
      :status_changes
    ])
  end

  def change_application(%JobApplication{} = application, attrs \\ %{}) do
    application
    |> Repo.preload(:tags)
    |> with_tag_names()
    |> JobApplication.changeset(attrs)
  end

  defp with_tag_names(%JobApplication{tag_names: nil, tags: tags} = application)
       when is_list(tags) do
    %{application | tag_names: Enum.map_join(tags, ", ", & &1.name)}
  end

  defp with_tag_names(application), do: application

  @doc """
  Creates an application and records its first status in the history.

  The company can be given as `company_id` or as a `company_name`, which is
  looked up (case-insensitively) or created.
  """
  def create_application(%User{} = user, attrs) do
    now = DateTime.utc_now(:second)
    changeset = JobApplication.changeset(%JobApplication{user_id: user.id, tags: []}, attrs)

    if changeset.valid?,
      do: insert_application(user, changeset, now),
      else: {:error, %{changeset | action: :insert}}
  end

  defp insert_application(user, changeset, now) do
    Multi.new()
    |> Multi.run(:company, fn _repo, _ -> resolve_company(user, changeset) end)
    |> Multi.run(:tags, fn _repo, _ -> upsert_tags(user, changeset) end)
    |> Multi.insert(:application, fn %{company: company, tags: tags} ->
      status = Ecto.Changeset.get_field(changeset, :status)

      changeset
      |> Ecto.Changeset.put_change(:company_id, company.id)
      |> Ecto.Changeset.put_change(:position, next_position(user, status))
      |> maybe_set_applied_on(user, status)
      |> JobApplication.put_tags(tags)
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
    application = Repo.preload(application, :tags)
    changeset = JobApplication.changeset(application, attrs)

    if changeset.valid?,
      do: save_application(user, application, changeset),
      else: {:error, %{changeset | action: :update}}
  end

  defp save_application(user, application, changeset) do
    Multi.new()
    |> Multi.run(:company, fn _repo, _ -> resolve_company(user, changeset) end)
    |> Multi.run(:tags, fn _repo, _ ->
      if Ecto.Changeset.get_change(changeset, :tag_names),
        do: upsert_tags(user, changeset),
        else: {:ok, application.tags}
    end)
    |> Multi.update(:application, fn %{company: company, tags: tags} ->
      status = Ecto.Changeset.get_field(changeset, :status)

      changeset
      |> Ecto.Changeset.put_change(:company_id, company.id)
      |> maybe_set_applied_on(user, status)
      |> JobApplication.put_tags(tags)
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
         id when is_integer(id) <- parse_id(id),
         %JobApplication{} = application <- Repo.get_by(JobApplication, id: id, user_id: user.id) do
      siblings =
        Repo.all(
          from a in JobApplication,
            where: a.user_id == ^user.id and a.status == ^status and a.id != ^application.id,
            order_by: [asc: a.position, desc: a.updated_at],
            select: a.id
        )

      index = index |> max(0) |> min(length(siblings))
      ordered = List.insert_at(siblings, index, application.id)

      changeset =
        application
        |> JobApplication.move_changeset(status, index)
        |> maybe_set_applied_on(user, status)

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

  ## Tags

  @doc """
  The user's tags with the number of applications using each one.
  """
  def list_tags(%User{} = user) do
    Repo.all(
      from t in Tag,
        left_join: at in "job_application_tags",
        on: at.tag_id == t.id,
        where: t.user_id == ^user.id,
        group_by: t.id,
        order_by: t.name,
        select_merge: %{usage_count: count(at.job_application_id)}
    )
  end

  def get_tag!(%User{} = user, id), do: Repo.get_by!(Tag, id: id, user_id: user.id)

  def create_tag(%User{} = user, attrs) do
    %Tag{user_id: user.id}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  def delete_tag(%Tag{} = tag), do: Repo.delete(tag)

  def change_tag(%Tag{} = tag, attrs \\ %{}), do: Tag.changeset(tag, attrs)

  defp upsert_tags(user, changeset) do
    names = changeset |> Ecto.Changeset.get_field(:tag_names) |> Tag.parse_names()

    existing = Repo.all(from t in Tag, where: t.user_id == ^user.id and t.name in ^names)
    existing_names = MapSet.new(existing, & &1.name)

    created =
      for name <- names, name not in existing_names do
        Repo.insert!(%Tag{user_id: user.id, name: name},
          on_conflict: {:replace, [:updated_at]},
          conflict_target: {:unsafe_fragment, "(user_id, lower(name))"}
        )
      end

    by_name = Map.new(existing ++ created, &{&1.name, &1})
    {:ok, Enum.map(names, &Map.fetch!(by_name, &1))}
  end
end
