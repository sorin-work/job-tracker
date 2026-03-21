defmodule JobTrackerWeb.HealthController do
  use JobTrackerWeb, :controller

  require Logger

  @doc """
  Liveness and readiness check used by Docker. Returns 503 when the database
  can't be reached.
  """
  def show(conn, _params) do
    case Ecto.Adapters.SQL.query(JobTracker.Repo, "SELECT 1", [], timeout: 2_000) do
      {:ok, _result} ->
        json(conn, %{status: "ok", database: "ok"})

      {:error, error} ->
        Logger.warning("health check failed: #{Exception.message(error)}")

        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", database: "unavailable"})
    end
  end
end
