defmodule JobTrackerWeb.BoardLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.PipelineFixtures

  alias JobTracker.Pipeline

  setup :register_and_log_in_user

  test "shows a column per status with the applications in it", %{conn: conn, user: user} do
    application_fixture(user, title: "Data Engineer", status: :screening, tag_names: "remote")

    {:ok, lv, _html} = live(conn, ~p"/board")

    for status <- JobTracker.Pipeline.Status.all() do
      assert has_element?(lv, "#column-#{status}")
    end

    assert lv |> element("#column-screening") |> render() =~ "Data Engineer"
    assert lv |> element("#column-screening") |> render() =~ "remote"
  end

  test "moving a card changes the status", %{conn: conn, user: user} do
    application = application_fixture(user, title: "Data Engineer")

    {:ok, lv, _html} = live(conn, ~p"/board")

    render_hook(lv, "move", %{
      "id" => to_string(application.id),
      "status" => "applied",
      "index" => 0
    })

    assert lv |> element("#column-applied") |> render() =~ "Data Engineer"
    refute lv |> element("#column-wishlist") |> render() =~ "Data Engineer"
    assert Pipeline.get_application!(user, application.id).status == :applied
  end

  test "an invalid move shows an error", %{conn: conn, user: user} do
    application = application_fixture(user)

    {:ok, lv, _html} = live(conn, ~p"/board")

    assert render_hook(lv, "move", %{
             "id" => to_string(application.id),
             "status" => "hired",
             "index" => 0
           }) =~
             "Could not move the application"
  end
end
