defmodule JobTracker.Repo.Migrations.AddPostingDetailsToJobApplications do
  use Ecto.Migration

  def change do
    alter table(:job_applications) do
      add :description, :text
      add :work_mode, :string
      add :source, :string
      add :priority, :integer, null: false, default: 2
    end
  end
end
