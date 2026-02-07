defmodule JobTracker.Repo.Migrations.AddPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :time_zone, :string, null: false, default: "Etc/UTC"
      add :weekly_goal, :integer
      add :follow_up_days, :integer
    end
  end
end
