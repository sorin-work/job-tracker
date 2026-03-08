defmodule JobTrackerWeb.StatsLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.PipelineFixtures

  alias JobTracker.Pipeline

  setup :register_and_log_in_user

  test "shows the funnel, response rate and weekly chart", %{conn: conn, user: user} do
    a = application_fixture(user, status: :applied, source: :referral)
    {:ok, _} = Pipeline.change_status(user, a, :screening)
    application_fixture(user, status: :applied, source: :linkedin)

    {:ok, lv, _html} = live(conn, ~p"/stats")

    assert lv |> element("#stat-response-rate") |> render() =~ "50%"
    assert lv |> element("#funnel-applied") |> render() =~ "2"
    assert lv |> element("#funnel-screening") |> render() =~ "50% of previous"
    assert has_element?(lv, "#weekly")
  end
end
