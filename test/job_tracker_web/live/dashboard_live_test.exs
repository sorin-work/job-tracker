defmodule JobTrackerWeb.DashboardLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.ActivityFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Accounts

  setup :register_and_log_in_user

  test "redirects visitors to the login page" do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(build_conn(), ~p"/dashboard")
  end

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

  test "completes and snoozes reminders", %{conn: conn, user: user} do
    done = reminder_fixture(user, title: "Email recruiter")
    snoozed = reminder_fixture(user, title: "Update resume")

    {:ok, lv, _html} = live(conn, ~p"/dashboard")

    assert lv |> element("#due-#{done.id} button", "Done") |> render_click() =~
             "Done: Email recruiter"

    refute has_element?(lv, "#due-#{done.id}")

    lv |> element("#due-#{snoozed.id} button", "Tomorrow") |> render_click()
    refute has_element?(lv, "#due-#{snoozed.id}")
    refute has_element?(lv, "#nav-due-count")
  end

  test "shows progress towards the weekly goal", %{conn: conn, user: user} do
    {:ok, _} = Accounts.update_user_preferences(user, %{weekly_goal: 4})
    application_fixture(user, status: :applied)

    {:ok, lv, _html} = live(conn, ~p"/dashboard")
    assert lv |> element("#weekly-goal") |> render() =~ "/ 4"
  end
end
