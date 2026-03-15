defmodule JobTracker.Stats.CalculationsTest do
  use ExUnit.Case, async: true

  alias JobTracker.Stats.Calculations

  defp history(statuses, opts \\ []) do
    base = ~U[2026-03-02 10:00:00Z]

    changes =
      statuses
      |> Enum.with_index()
      |> Enum.map(fn {status, i} -> {status, DateTime.add(base, i * 3, :day)} end)

    %{
      status: List.last(statuses),
      changes: changes,
      applied_on: Keyword.get(opts, :applied_on, if(:applied in statuses, do: ~D[2026-03-02])),
      source: Keyword.get(opts, :source)
    }
  end

  describe "furthest_rank/1" do
    test "uses the furthest stage in the history" do
      assert Calculations.furthest_rank(history([:applied, :screening, :rejected])) == 2
      assert Calculations.furthest_rank(history([:wishlist])) == 0
      assert Calculations.furthest_rank(history([:applied, :interviewing])) == 3
    end
  end

  describe "funnel/1" do
    test "counts applications that reached each stage" do
      histories = [
        history([:applied]),
        history([:applied, :rejected]),
        history([:applied, :screening, :rejected]),
        history([:applied, :screening, :interviewing]),
        history([:applied, :screening, :interviewing, :offer, :accepted]),
        history([:wishlist])
      ]

      funnel = Calculations.funnel(histories)

      assert Enum.map(funnel, &{&1.status, &1.count}) == [
               applied: 5,
               screening: 3,
               interviewing: 2,
               offer: 1,
               accepted: 1
             ]

      assert [%{from_previous: nil, from_applied: 100.0}, %{from_previous: 60.0} | _] = funnel
      assert List.last(funnel).from_applied == 20.0
    end
  end

  describe "response_rate/1" do
    test "counts screens, interviews and rejections as responses" do
      histories = [
        history([:applied]),
        history([:applied, :withdrawn]),
        history([:applied, :rejected]),
        history([:applied, :screening]),
        history([:wishlist])
      ]

      assert Calculations.response_rate(histories) == 50.0
    end

    test "is nil without submitted applications" do
      assert Calculations.response_rate([history([:wishlist])]) == nil
    end
  end

  test "average_days_to_response/1" do
    histories = [
      # responses come 3 days after each step in the helper
      history([:applied, :screening]),
      history([:applied, :applied, :rejected]),
      history([:applied])
    ]

    assert Calculations.average_days_to_response(histories) == 4.5
    assert Calculations.average_days_to_response([history([:applied])]) == nil
  end

  describe "weekly_counts/3" do
    test "groups by monday-based weeks and fills empty weeks" do
      dates = [~D[2026-03-02], ~D[2026-03-08], ~D[2026-03-09], nil, ~D[2026-01-05]]

      assert Calculations.weekly_counts(dates, ~D[2026-03-11], 3) == [
               %{week: ~D[2026-02-23], count: 0},
               %{week: ~D[2026-03-02], count: 2},
               %{week: ~D[2026-03-09], count: 1}
             ]
    end
  end

  test "by_source/1 sorts by count and computes response rates" do
    histories = [
      history([:applied, :screening], source: :referral),
      history([:applied], source: :linkedin),
      history([:applied, :rejected], source: :linkedin),
      history([:applied], source: :linkedin),
      history([:wishlist], source: :referral)
    ]

    assert Calculations.by_source(histories) == [
             %{source: :linkedin, count: 3, response_rate: 33.3},
             %{source: :referral, count: 1, response_rate: 100.0}
           ]
  end

  test "outcomes/1 counts closed statuses" do
    histories = [
      history([:applied, :rejected]),
      history([:applied, :rejected]),
      history([:applied])
    ]

    assert Calculations.outcomes(histories) == %{accepted: 0, rejected: 2, withdrawn: 0}
  end
end
