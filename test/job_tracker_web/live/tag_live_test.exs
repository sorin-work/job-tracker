defmodule JobTrackerWeb.TagLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.PipelineFixtures

  setup :register_and_log_in_user

  test "lists tags with usage counts", %{conn: conn, user: user} do
    application_fixture(user, tag_names: "remote")
    application_fixture(user, tag_names: "remote, fintech")

    {:ok, _lv, html} = live(conn, ~p"/tags")
    assert html =~ "remote"
    assert html =~ "2 applications"
    assert html =~ "1 application"
  end
end
