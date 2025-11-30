defmodule JobTrackerWeb.PageControllerTest do
  use JobTrackerWeb.ConnCase

  import JobTracker.AccountsFixtures

  test "GET / shows the landing page to visitors", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Keep your job search on track"
    assert html =~ ~p"/users/register"
  end

  test "GET / sends logged in users to their applications", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/")
    assert redirected_to(conn) == ~p"/applications"
  end
end
