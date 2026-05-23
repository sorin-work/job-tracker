defmodule JobTracker.Repo.Migrations.AddIndexesForDueLists do
  use Ecto.Migration

  def change do
    create index(:reminders, [:user_id, :due_on],
             where: "completed_at IS NULL",
             name: :reminders_open_due_on_index
           )

    create index(:interviews, [:scheduled_at])
    create index(:job_applications, [:user_id, :applied_on])
  end
end
