defmodule JobTrackerWeb.ExportController do
  use JobTrackerWeb, :controller

  alias JobTracker.Export
  alias JobTracker.TimeZones

  def applications(conn, _params) do
    user = conn.assigns.current_user
    filename = "applications-#{Date.to_iso8601(TimeZones.today(user))}.csv"

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
    |> send_resp(200, Export.applications_csv(user))
  end
end
