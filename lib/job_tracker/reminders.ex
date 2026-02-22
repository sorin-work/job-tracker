defmodule JobTracker.Reminders do
  @moduledoc """
  Follow-up reminders, optionally attached to an application.

  "Today" is always the date in the user's time zone.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts.User
  alias JobTracker.Pipeline.JobApplication
  alias JobTracker.Reminders.Reminder
  alias JobTracker.Repo
  alias JobTracker.TimeZones

  @doc """
  Open reminders that are due today or earlier, oldest first.
  """
  def list_due(%User{} = user) do
    today = TimeZones.today(user)

    user
    |> open_query()
    |> where([r], r.due_on <= ^today)
    |> order_by([r], asc: r.due_on, asc: r.id)
    |> Repo.all()
    |> Repo.preload(job_application: :company)
  end

  @doc """
  Number of open reminders due today or earlier, for the navigation badge.
  """
  def count_due(%User{} = user) do
    today = TimeZones.today(user)

    user
    |> open_query()
    |> where([r], r.due_on <= ^today)
    |> Repo.aggregate(:count)
  end

  @doc """
  Reminders grouped for the reminders page: `:overdue`, `:today`, `:upcoming`
  and the 20 most recently `:completed`.
  """
  def grouped(%User{} = user) do
    today = TimeZones.today(user)

    open =
      user
      |> open_query()
      |> order_by([r], asc: r.due_on, asc: r.id)
      |> Repo.all()
      |> Repo.preload(job_application: :company)

    completed =
      Reminder
      |> where([r], r.user_id == ^user.id and not is_nil(r.completed_at))
      |> order_by([r], desc: r.completed_at)
      |> Repo.all()
      |> Repo.preload(job_application: :company)

    %{
      overdue: Enum.filter(open, &(Date.compare(&1.due_on, today) == :lt)),
      today: Enum.filter(open, &(Date.compare(&1.due_on, today) == :eq)),
      upcoming: Enum.filter(open, &(Date.compare(&1.due_on, today) == :gt)),
      completed: completed
    }
  end

  defp open_query(user) do
    where(Reminder, [r], r.user_id == ^user.id and is_nil(r.completed_at))
  end

  def get_reminder!(%User{} = user, id) do
    Reminder
    |> Repo.get_by!(id: id, user_id: user.id)
    |> Repo.preload(job_application: :company)
  end

  def create_reminder(%User{} = user, attrs) do
    %Reminder{user_id: user.id}
    |> Reminder.changeset(attrs)
    |> validate_application_owner(user)
    |> Repo.insert()
  end

  def update_reminder(%User{} = user, %Reminder{} = reminder, attrs) do
    reminder
    |> Reminder.changeset(attrs)
    |> validate_application_owner(user)
    |> Repo.update()
  end

  # The application id comes from a form, so make sure it is one of the user's.
  defp validate_application_owner(changeset, user) do
    case Ecto.Changeset.get_change(changeset, :job_application_id) do
      nil ->
        changeset

      id ->
        if Repo.exists?(from a in JobApplication, where: a.id == ^id and a.user_id == ^user.id) do
          changeset
        else
          Ecto.Changeset.add_error(changeset, :job_application_id, "is not valid")
        end
    end
  end

  def complete_reminder(%Reminder{} = reminder) do
    reminder
    |> Ecto.Changeset.change(completed_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  def reopen_reminder(%Reminder{} = reminder) do
    reminder
    |> Ecto.Changeset.change(completed_at: nil)
    |> Repo.update()
  end

  @doc """
  Moves a reminder's due date `days` days past today.
  """
  def snooze_reminder(%User{} = user, %Reminder{} = reminder, days) when days > 0 do
    reminder
    |> Ecto.Changeset.change(due_on: Date.add(TimeZones.today(user), days))
    |> Repo.update()
  end

  def delete_reminder(%Reminder{} = reminder), do: Repo.delete(reminder)

  def change_reminder(%Reminder{} = reminder, attrs \\ %{}),
    do: Reminder.changeset(reminder, attrs)
end
