# Script for populating the database. You can run it as:
#
#     SEED_DEMO=true mix run priv/repo/seeds.exs
#
# With SEED_DEMO=true it creates demo@example.com / demo-password with a few
# months of sample data. Running it again leaves an existing demo user alone.

if System.get_env("SEED_DEMO") in ~w(true 1) do
  case JobTracker.Demo.seed() do
    {:ok, _user} ->
      IO.puts("Created demo user #{JobTracker.Demo.email()} / #{JobTracker.Demo.password()}")

    {:error, :exists} ->
      IO.puts("Demo user already exists")
  end
end
