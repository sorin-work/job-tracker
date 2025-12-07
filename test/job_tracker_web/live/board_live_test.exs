defmodule JobTrackerWeb.BoardLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.PipelineFixtures

  setup :register_and_log_in_user

  test "shows a column per status with the applications in it", %{conn: conn, user: user} do
    application_fixture(user, title: "Data Engineer", status: :screening)

    {:ok, lv, _html} = live(conn, ~p"/board")

    for status <- JobTracker.Pipeline.Status.all() do
      assert has_element?(lv, "#column-#{status}")
    end

    assert lv |> element("#column-screening") |> render() =~ "Data Engineer"
  end
end
