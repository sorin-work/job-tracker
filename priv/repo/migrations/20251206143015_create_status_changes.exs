defmodule JobTracker.Repo.Migrations.CreateStatusChanges do
  use Ecto.Migration

  def change do
    create table(:status_changes) do
      add :job_application_id, references(:job_applications, on_delete: :delete_all), null: false
      add :from_status, :string
      add :to_status, :string, null: false
      add :note, :string
      add :changed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:status_changes, [:job_application_id, :changed_at])
  end
end
