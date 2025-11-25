defmodule JobTracker.Repo do
  use Ecto.Repo,
    otp_app: :job_tracker,
    adapter: Ecto.Adapters.Postgres
end
