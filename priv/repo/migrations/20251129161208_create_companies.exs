defmodule JobTracker.Repo.Migrations.CreateCompanies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :website, :string
      add :industry, :string
      add :location, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:companies, [:user_id])

    create unique_index(:companies, [:user_id, "lower(name)"],
             name: :companies_user_id_name_index
           )
  end
end
