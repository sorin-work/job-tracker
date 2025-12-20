defmodule JobTracker.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :color, :string, null: false, default: "zinc"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:user_id, "lower(name)"], name: :tags_user_id_name_index)

    create table(:job_application_tags, primary_key: false) do
      add :job_application_id, references(:job_applications, on_delete: :delete_all), null: false

      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:job_application_tags, [:job_application_id, :tag_id])
    create index(:job_application_tags, [:tag_id])
  end
end
