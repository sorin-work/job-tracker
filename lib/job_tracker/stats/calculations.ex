defmodule JobTracker.Stats.Calculations do
  @moduledoc """
  The arithmetic behind the stats page, kept free of database access so it is
  easy to test.

  Most functions take a list of "histories": one map per application with its
  `:status`, `:applied_on`, `:source` and the `:changes` it went through, each
  change being `{to_status, changed_at}` in chronological order.
  """

  alias JobTracker.Pipeline.Status

  @funnel_stages [:applied, :screening, :interviewing, :offer, :accepted]
  @response_statuses [:screening, :interviewing, :offer, :accepted, :rejected]

  def funnel_stages, do: @funnel_stages

  @doc """
  The furthest stage an application reached along the normal progression,
  as a rank (0 = wishlist). Skipped stages count as reached: an application
  that went straight from applied to interviewing has passed screening too.
  Rejected or withdrawn applications keep the rank they had before closing.
  """
  def furthest_rank(%{status: status, changes: changes}) do
    [status | Enum.map(changes, &elem(&1, 0))]
    |> Enum.map(&Status.rank/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.max(fn -> 0 end)
  end

  @doc """
  Whether an application ever left the wishlist.
  """
  def submitted?(history), do: furthest_rank(history) >= 1 or not is_nil(history.applied_on)

  @doc """
  Counts how many applications reached each stage from applied onwards, with
  the conversion from the previous stage and from applied, as percentages.
  """
  def funnel(histories) do
    ranks = histories |> Enum.filter(&submitted?/1) |> Enum.map(&max(furthest_rank(&1), 1))
    applied = length(ranks)

    {stages, _previous} =
      Enum.map_reduce(@funnel_stages, nil, fn stage, previous ->
        rank = Status.rank(stage)
        count = Enum.count(ranks, &(&1 >= rank))

        row = %{
          status: stage,
          count: count,
          from_previous: if(previous, do: percent(count, previous)),
          from_applied: percent(count, applied)
        }

        {row, count}
      end)

    stages
  end

  @doc """
  The first time a company got back: moved the application to screening or
  further, or rejected it. Returns nil when there was no response.
  """
  def first_response_at(%{changes: changes}) do
    Enum.find_value(changes, fn {to_status, at} -> if to_status in @response_statuses, do: at end)
  end

  @doc """
  Share of submitted applications that got any response, as a percentage
  (nil when nothing was submitted yet).
  """
  def response_rate(histories) do
    submitted = Enum.filter(histories, &submitted?/1)
    responded = Enum.count(submitted, &first_response_at/1)
    percent(responded, length(submitted))
  end

  @doc """
  Average number of days between applying and the first response, over the
  applications that got one and have an application date.
  """
  def average_days_to_response(histories) do
    days =
      for %{applied_on: %Date{} = applied_on} = history <- histories,
          at = first_response_at(history),
          do: max(Date.diff(DateTime.to_date(at), applied_on), 0)

    case days do
      [] -> nil
      days -> Float.round(Enum.sum(days) / length(days), 1)
    end
  end

  @doc """
  Number of applications per week (by application date) for the `weeks` weeks
  up to and including the one `today` falls in. Weeks start on Monday and
  weeks without applications are included with a count of 0.
  """
  def weekly_counts(dates, %Date{} = today, weeks) when weeks > 0 do
    current = Date.beginning_of_week(today, :monday)
    first = Date.add(current, -7 * (weeks - 1))

    counts =
      dates
      |> Enum.reject(&is_nil/1)
      |> Enum.map(&Date.beginning_of_week(&1, :monday))
      |> Enum.frequencies()

    for offset <- 0..(weeks - 1) do
      week = Date.add(first, offset * 7)
      %{week: week, count: Map.get(counts, week, 0)}
    end
  end

  @doc """
  Response rate per source, for sources with at least one submitted
  application, ordered by the number of applications.
  """
  def by_source(histories) do
    histories
    |> Enum.filter(&submitted?/1)
    |> Enum.group_by(& &1.source)
    |> Enum.map(fn {source, group} ->
      %{source: source, count: length(group), response_rate: response_rate(group)}
    end)
    |> Enum.sort_by(&{-&1.count, to_string(&1.source)})
  end

  @doc """
  How closed applications ended.
  """
  def outcomes(histories) do
    counts = Enum.frequencies_by(histories, & &1.status)
    Map.new(Status.closed(), &{&1, Map.get(counts, &1, 0)})
  end

  def percent(_part, 0), do: nil
  def percent(part, whole), do: Float.round(part * 100 / whole, 1)
end
