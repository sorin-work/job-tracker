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
end
