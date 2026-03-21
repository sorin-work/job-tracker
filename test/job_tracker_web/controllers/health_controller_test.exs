defmodule JobTrackerWeb.HealthControllerTest do
  use JobTrackerWeb.ConnCase, async: true

  test "GET /health reports the app and database as ok", %{conn: conn} do
    conn = get(conn, ~p"/health")
    assert json_response(conn, 200) == %{"status" => "ok", "database" => "ok"}
  end
end
