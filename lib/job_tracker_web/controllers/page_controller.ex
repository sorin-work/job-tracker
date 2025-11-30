defmodule JobTrackerWeb.PageController do
  use JobTrackerWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/applications")
    else
      render(conn, :home, page_title: "Keep your job search on track")
    end
  end
end
