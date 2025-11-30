defmodule JobTracker.Repo.Migrations.CreateJobApplications do
  use Ecto.Migration

  def change do
    create table(:job_applications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :status, :string, null: false, default: "wishlist"
      add :location, :string
      add :posting_url, :string
      add :applied_on, :date
      add :salary_min, :integer
      add :salary_max, :integer
      add :salary_currency, :string, size: 3, null: false, default: "USD"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:job_applications, [:user_id, :status])
    create index(:job_applications, [:company_id])
  end
end
