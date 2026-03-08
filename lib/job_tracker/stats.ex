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
  """
  def summary(%User{} = user, opts \\ []) do
    histories = histories(user)
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

  defp histories(user) do
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
end
