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

  test "renames and deletes a tag", %{conn: conn, user: user} do
    tag = tag_fixture(user, name: "remote")

    {:ok, lv, _html} = live(conn, ~p"/tags/#{tag}/edit")

    html =
      lv |> form("#tag-form", tag: %{name: "Remote first", color: "emerald"}) |> render_submit()

    assert html =~ "remote first"

    lv |> element("#tag-#{tag.id} button", "Delete") |> render_click()
    refute has_element?(lv, "#tag-#{tag.id}")
  end
end
