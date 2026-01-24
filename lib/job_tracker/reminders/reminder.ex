defmodule JobTracker.Reminders.Reminder do
  @moduledoc """
  A follow-up reminder, optionally tied to an application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  import JobTracker.Validation

  schema "reminders" do
    field :title, :string
    field :due_on, :date
    field :notes, :string
    field :completed_at, :utc_datetime

    belongs_to :user, JobTracker.Accounts.User
    belongs_to :job_application, JobTracker.Pipeline.JobApplication

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:title, :due_on, :notes, :job_application_id])
    |> trim_fields([:title, :notes])
    |> validate_required([:title, :due_on])
    |> validate_length(:title, max: 160)
    |> assoc_constraint(:job_application)
  end

  def completed?(%__MODULE__{completed_at: completed_at}), do: not is_nil(completed_at)
end
