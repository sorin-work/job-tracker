defmodule JobTracker.Repo.Migrations.CreateReminders do
  use Ecto.Migration

  def change do
    create table(:reminders) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :job_application_id, references(:job_applications, on_delete: :delete_all)
      add :title, :string, null: false
      add :due_on, :date, null: false
      add :notes, :text
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:reminders, [:user_id])
    create index(:reminders, [:job_application_id])
  end
end
