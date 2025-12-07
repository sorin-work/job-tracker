defmodule JobTracker.Repo.Migrations.AddPositionToJobApplications do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :position, :integer, null: false, default: 0
    end
  end
end
