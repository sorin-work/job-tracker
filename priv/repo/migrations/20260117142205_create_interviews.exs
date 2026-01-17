defmodule JobTracker.Repo.Migrations.CreateInterviews do
  use Ecto.Migration

  def change do
    create table(:interviews) do
      add :job_application_id, references(:job_applications, on_delete: :delete_all), null: false
      add :scheduled_at, :utc_datetime, null: false
      add :duration_minutes, :integer, null: false, default: 60
      add :kind, :string, null: false
      add :location, :string
      add :interviewers, :string
      add :prep_notes, :text
      add :outcome, :string, null: false, default: "pending"
      add :feedback, :text

      timestamps(type: :utc_datetime)
    end

    create index(:interviews, [:job_application_id])
  end
end
