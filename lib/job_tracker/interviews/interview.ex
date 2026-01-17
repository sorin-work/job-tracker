defmodule JobTracker.Interviews.Interview do
  @moduledoc """
  An interview for an application.
  """

  use Ecto.Schema
  import Ecto.Changeset

  import JobTracker.Validation

  alias JobTracker.TimeZones

  @kinds [
    :phone_screen,
    :recruiter,
    :technical,
    :take_home,
    :behavioral,
    :system_design,
    :onsite,
    :final,
    :other
  ]
  @outcomes [:pending, :passed, :failed, :cancelled]

  schema "interviews" do
    field :scheduled_at, :utc_datetime
    field :local_scheduled_at, :naive_datetime, virtual: true
    field :duration_minutes, :integer, default: 60
    field :kind, Ecto.Enum, values: @kinds
    field :location, :string
    field :interviewers, :string
    field :prep_notes, :string
    field :outcome, Ecto.Enum, values: @outcomes, default: :pending
    field :feedback, :string

    belongs_to :job_application, JobTracker.Pipeline.JobApplication

    timestamps(type: :utc_datetime)
  end

  def kinds, do: @kinds
  def outcomes, do: @outcomes

  def kind_label(kind) do
    kind |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  @doc """
  The form works with the wall-clock time in the user's time zone
  (`local_scheduled_at`); it is converted to UTC for `scheduled_at`.
  """
  def changeset(interview, attrs, time_zone) do
    interview
    |> cast(attrs, [
      :local_scheduled_at,
      :duration_minutes,
      :kind,
      :location,
      :interviewers,
      :prep_notes,
      :outcome,
      :feedback
    ])
    |> trim_fields([:location, :interviewers, :prep_notes, :feedback])
    |> validate_required([:local_scheduled_at, :duration_minutes, :kind, :outcome])
    |> validate_number(:duration_minutes, greater_than: 0)
    |> validate_length(:location, max: 500)
    |> validate_length(:interviewers, max: 255)
    |> put_scheduled_at(time_zone)
  end

  defp put_scheduled_at(changeset, time_zone) do
    case get_change(changeset, :local_scheduled_at) do
      nil -> changeset
      local -> put_change(changeset, :scheduled_at, TimeZones.from_local(local, time_zone))
    end
  end

  @doc """
  Fills the virtual local time from `scheduled_at`, for edit forms.
  """
  def with_local_time(%__MODULE__{scheduled_at: nil} = interview, _user), do: interview

  def with_local_time(%__MODULE__{scheduled_at: scheduled_at} = interview, user) do
    local = scheduled_at |> TimeZones.to_local(user) |> DateTime.to_naive()
    %{interview | local_scheduled_at: local}
  end

  def ends_at(%__MODULE__{scheduled_at: at, duration_minutes: minutes}) do
    DateTime.add(at, minutes, :minute)
  end
end
