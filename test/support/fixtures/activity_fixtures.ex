defmodule JobTracker.ActivityFixtures do
  @moduledoc """
  Test helpers for contacts, interviews and reminders.
  """

  def contact_fixture(user, attrs \\ %{}) do
    {:ok, contact} =
      JobTracker.Contacts.create_contact(
        user,
        Enum.into(attrs, %{name: "Jane Doe", title: "Recruiter", email: "jane@example.com"})
      )

    contact
  end

  def interview_fixture(user, application, attrs \\ %{}) do
    local =
      DateTime.utc_now()
      |> DateTime.add(2, :day)
      |> DateTime.to_naive()
      |> NaiveDateTime.truncate(:second)

    {:ok, interview} =
      JobTracker.Interviews.create_interview(
        user,
        application,
        Enum.into(attrs, %{local_scheduled_at: local, duration_minutes: 45, kind: :technical})
      )

    interview
  end
end
