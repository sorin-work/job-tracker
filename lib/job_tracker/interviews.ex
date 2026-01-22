defmodule JobTracker.Interviews do
  @moduledoc """
  Interviews scheduled for an application.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts.User
  alias JobTracker.Interviews.Interview
  alias JobTracker.Pipeline.JobApplication
  alias JobTracker.Repo
  alias JobTracker.TimeZones

  defp user_query(%User{id: user_id}) do
    from i in Interview,
      join: a in assoc(i, :job_application),
      as: :application,
      where: a.user_id == ^user_id
  end

  @doc """
  Interviews that haven't ended yet, soonest first.

  ## Options

    * `:within_days` - only interviews starting in the next N days
  """
  def list_upcoming(%User{} = user, opts \\ []) do
    now = DateTime.utc_now()

    user
    |> user_query()
    |> where([i], i.outcome != :cancelled)
    |> where([i], i.scheduled_at >= ^now)
    |> maybe_within(opts[:within_days], now)
    |> order_by([i], asc: i.scheduled_at)
    |> Repo.all()
    |> Repo.preload(job_application: :company)
  end

  defp maybe_within(query, nil, _now), do: query

  defp maybe_within(query, days, now) do
    where(query, [i], i.scheduled_at <= ^DateTime.add(now, days, :day))
  end

  @doc """
  Interviews that have already happened, most recent first.
  """
  def list_past(%User{} = user, limit \\ 50) do
    now = DateTime.utc_now()

    user
    |> user_query()
    |> where(
      [i],
      fragment("? + make_interval(mins => ?)", i.scheduled_at, i.duration_minutes) < ^now
    )
    |> order_by([i], desc: i.scheduled_at)
    |> limit(^limit)
    |> Repo.all()
    |> Repo.preload(job_application: :company)
  end

  def get_interview!(%User{} = user, id) do
    user
    |> user_query()
    |> where([i], i.id == ^id)
    |> Repo.one!()
    |> Repo.preload(job_application: :company)
  end

  def create_interview(%User{} = user, %JobApplication{} = application, attrs) do
    if application.user_id != user.id,
      do: raise(ArgumentError, "application belongs to another user")

    %Interview{job_application_id: application.id}
    |> Interview.changeset(attrs, TimeZones.zone(user))
    |> Repo.insert()
  end

  def update_interview(%User{} = user, %Interview{} = interview, attrs) do
    interview
    |> Interview.with_local_time(user)
    |> Interview.changeset(attrs, TimeZones.zone(user))
    |> Repo.update()
  end

  def delete_interview(%Interview{} = interview), do: Repo.delete(interview)

  def change_interview(%User{} = user, %Interview{} = interview, attrs \\ %{}) do
    interview
    |> Interview.with_local_time(user)
    |> Interview.changeset(attrs, TimeZones.zone(user))
  end
end
