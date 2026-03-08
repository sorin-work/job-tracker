defmodule JobTracker.StatsTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Pipeline
  alias JobTracker.Stats

  setup do
    %{user: user_fixture()}
  end

  test "summary/2 builds the stats from applications and their history", %{user: user} do
    a = application_fixture(user, status: :applied)
    {:ok, _} = Pipeline.change_status(user, a, :screening)
    b = application_fixture(user, status: :applied)
    {:ok, _} = Pipeline.change_status(user, b, :rejected)
    application_fixture(user, status: :applied)
    application_fixture(user)
    application_fixture(user_fixture(), status: :applied)

    summary = Stats.summary(user)

    assert summary.total == 4
    assert summary.submitted == 3
    assert summary.response_rate == 66.7
    assert summary.average_days_to_response == 0.0
    assert [%{status: :applied, count: 3}, %{status: :screening, count: 1} | _] = summary.funnel
    assert length(summary.weekly) == 12
    assert List.last(summary.weekly).count == 3
    assert summary.outcomes.rejected == 1
  end
end
