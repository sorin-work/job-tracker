defmodule JobTrackerWeb.ExportControllerTest do
  use JobTrackerWeb.ConnCase, async: true

  import JobTracker.PipelineFixtures

  setup :register_and_log_in_user

  test "downloads the applications as csv", %{conn: conn, user: user} do
    application_fixture(user, title: "Platform Engineer")

    conn = get(conn, ~p"/export/applications.csv")

    assert response_content_type(conn, :csv) =~ "text/csv"
    assert [disposition] = get_resp_header(conn, "content-disposition")
    assert disposition =~ ~r/attachment; filename="applications-\d{4}-\d{2}-\d{2}\.csv"/
    assert response(conn, 200) =~ "Platform Engineer"
  end

  test "requires a logged in user" do
    conn = get(build_conn(), ~p"/export/applications.csv")
    assert redirected_to(conn) == ~p"/users/log_in"
  end
end
