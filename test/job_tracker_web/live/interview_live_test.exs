defmodule JobTrackerWeb.InterviewLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.ActivityFixtures
  import JobTracker.PipelineFixtures

  setup :register_and_log_in_user

  test "lists upcoming and past interviews", %{conn: conn, user: user} do
    application = application_fixture(user, title: "Platform Engineer", status: :interviewing)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    upcoming =
      interview_fixture(user, application, %{local_scheduled_at: NaiveDateTime.add(now, 1, :day)})

    past =
      interview_fixture(user, application, %{
        local_scheduled_at: NaiveDateTime.add(now, -3, :day),
        kind: :phone_screen
      })

    {:ok, lv, _html} = live(conn, ~p"/interviews")

    assert has_element?(lv, "#upcoming-#{upcoming.id}")
    assert has_element?(lv, "#past-#{past.id}", "Phone screen")
  end
end
