defmodule JobTrackerWeb.DashboardLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.ActivityFixtures
  import JobTracker.PipelineFixtures

  setup :register_and_log_in_user

  test "shows pipeline counts, due reminders and upcoming interviews", %{conn: conn, user: user} do
    application = application_fixture(user, title: "Platform Engineer", status: :interviewing)
    interview_fixture(user, application, %{kind: :system_design})
    reminder_fixture(user, title: "Send thank-you note", due_on: Date.add(Date.utc_today(), -1))
    reminder_fixture(user, title: "Not yet", due_on: Date.add(Date.utc_today(), 3))

    {:ok, lv, html} = live(conn, ~p"/dashboard")

    assert lv |> element("#stat-interviewing") |> render() =~ "1"
    assert html =~ "Send thank-you note"
    assert html =~ "yesterday"
    refute html =~ "Not yet"
    assert lv |> element("#upcoming-interviews") |> render() =~ "System design"
    assert lv |> element("#nav-due-count") |> render() =~ "1"
  end
end
