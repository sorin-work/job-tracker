defmodule JobTrackerWeb.ReminderLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.ActivityFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Reminders

  setup :register_and_log_in_user

  test "groups reminders by when they are due", %{conn: conn, user: user} do
    overdue =
      reminder_fixture(user, title: "Overdue thing", due_on: Date.add(Date.utc_today(), -2))

    today = reminder_fixture(user, title: "Today thing")
    later = reminder_fixture(user, title: "Later thing", due_on: Date.add(Date.utc_today(), 5))

    {:ok, lv, _html} = live(conn, ~p"/reminders")

    assert has_element?(lv, "#overdue #reminder-#{overdue.id}")
    assert has_element?(lv, "#today #reminder-#{today.id}")
    assert has_element?(lv, "#upcoming #reminder-#{later.id}")
  end

  test "creates a reminder tied to an application", %{conn: conn, user: user} do
    application = application_fixture(user, title: "Platform Engineer")
    {:ok, lv, _html} = live(conn, ~p"/reminders/new")

    assert lv |> form("#reminder-form", reminder: %{title: ""}) |> render_change() =~
             "can&#39;t be blank"

    lv |> element("#reminder-form button", "In a week") |> render_click()

    html =
      lv
      |> form("#reminder-form",
        reminder: %{title: "Check in", job_application_id: application.id}
      )
      |> render_submit()

    assert_patch(lv, ~p"/reminders")
    assert html =~ "Reminder saved"
    assert [%{due_on: due_on, job_application_id: app_id}] = Reminders.grouped(user).upcoming
    assert due_on == Date.add(Date.utc_today(), 7)
    assert app_id == application.id
  end
end
