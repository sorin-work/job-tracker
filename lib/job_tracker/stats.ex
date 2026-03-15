defmodule JobTracker.Stats do
  @moduledoc """
  Numbers for the stats page and the dashboard.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts.User
  alias JobTracker.Pipeline.{JobApplication, StatusChange}
  alias JobTracker.Repo
  alias JobTracker.Stats.Calculations
  alias JobTracker.TimeZones

  @doc """
  Everything the stats page shows.

  ## Options

    * `:weeks` - how many weeks the weekly chart covers (default 12)
    * `:since` - only count applications created on or after this date
  """
  def summary(%User{} = user, opts \\ []) do
    histories = histories(user, opts[:since])
    today = TimeZones.today(user)

    %{
      total: length(histories),
      submitted: Enum.count(histories, &Calculations.submitted?/1),
      funnel: Calculations.funnel(histories),
      response_rate: Calculations.response_rate(histories),
      average_days_to_response: Calculations.average_days_to_response(histories),
      weekly:
        Calculations.weekly_counts(
          Enum.map(histories, & &1.applied_on),
          today,
          opts[:weeks] || 12
        ),
      by_source: Calculations.by_source(histories),
      outcomes: Calculations.outcomes(histories)
    }
  end

  @doc """
  Applications submitted this week (Monday to today) against the user's
  weekly goal.
  """
  def weekly_goal_progress(%User{} = user) do
    week_start = user |> TimeZones.today() |> TimeZones.week_start()

    count =
      Repo.aggregate(
        from(a in JobApplication, where: a.user_id == ^user.id and a.applied_on >= ^week_start),
        :count
      )

    %{count: count, goal: user.weekly_goal}
  end

  defp histories(user, since) do
    applications =
      Repo.all(
        from a in JobApplication,
          where: a.user_id == ^user.id,
          select: %{
            id: a.id,
            status: a.status,
            applied_on: a.applied_on,
            source: a.source,
            inserted_at: a.inserted_at
          }
      )
      |> filter_since(since)

    ids = Enum.map(applications, & &1.id)

    changes =
      Repo.all(
        from s in StatusChange,
          where: s.job_application_id in ^ids,
          order_by: [asc: s.changed_at, asc: s.id],
          select: {s.job_application_id, s.to_status, s.changed_at}
      )
      |> Enum.group_by(&elem(&1, 0), fn {_id, to_status, at} -> {to_status, at} end)

    Enum.map(applications, &Map.put(&1, :changes, Map.get(changes, &1.id, [])))
  end

  defp filter_since(applications, nil), do: applications

  defp filter_since(applications, %Date{} = since) do
    Enum.filter(applications, &(Date.compare(DateTime.to_date(&1.inserted_at), since) != :lt))
  end
end
