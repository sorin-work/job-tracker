defmodule JobTracker.Release do
  @moduledoc """
  Tasks run from the release, where Mix isn't available:

      bin/job_tracker eval "JobTracker.Release.migrate()"
      bin/job_tracker eval "JobTracker.Release.seed_demo()"
  """

  @app :job_tracker

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Creates the demo account unless it already exists.
  """
  def seed_demo do
    load_app()
    {:ok, _} = Application.ensure_all_started(:tzdata)

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, fn _repo -> run_demo_seed() end)
    end
  end

  defp run_demo_seed do
    case JobTracker.Demo.seed() do
      {:ok, _user} -> IO.puts("Created demo user #{JobTracker.Demo.email()}")
      {:error, :exists} -> IO.puts("Demo user already exists, skipping")
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_loaded(@app)
  end
end
