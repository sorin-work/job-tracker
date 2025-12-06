defmodule JobTracker.Pipeline.StatusChange do
  @moduledoc """
  One step in an application's status history.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias JobTracker.Pipeline.Status

  schema "status_changes" do
    field :from_status, Ecto.Enum, values: Status.all()
    field :to_status, Ecto.Enum, values: Status.all()
    field :note, :string
    field :changed_at, :utc_datetime

    belongs_to :job_application, JobTracker.Pipeline.JobApplication

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(status_change, attrs) do
    status_change
    |> cast(attrs, [:from_status, :to_status, :note, :changed_at])
    |> validate_required([:to_status, :changed_at])
    |> validate_length(:note, max: 255)
  end
end
