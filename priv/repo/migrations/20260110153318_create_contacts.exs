defmodule JobTracker.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :nilify_all)
      add :name, :string, null: false
      add :title, :string
      add :email, :string
      add :phone, :string
      add :linkedin_url, :string
      add :notes, :text
      add :last_contacted_on, :date

      timestamps(type: :utc_datetime)
    end

    create index(:contacts, [:user_id])
    create index(:contacts, [:company_id])
  end
end
