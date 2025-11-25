defmodule JobTracker.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      JobTrackerWeb.Telemetry,
      JobTracker.Repo,
      {DNSCluster, query: Application.get_env(:job_tracker, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: JobTracker.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: JobTracker.Finch},
      # Start a worker by calling: JobTracker.Worker.start_link(arg)
      # {JobTracker.Worker, arg},
      # Start to serve requests, typically the last entry
      JobTrackerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: JobTracker.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    JobTrackerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
