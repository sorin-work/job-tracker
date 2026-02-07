defmodule JobTracker.InterviewsTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.ActivityFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Accounts
  alias JobTracker.Interviews
  alias JobTracker.Interviews.Interview

  setup do
    user = user_fixture()
    %{user: user, application: application_fixture(user, status: :interviewing)}
  end

  describe "create_interview/3" do
    test "stores the time in UTC from the user's time zone", %{
      user: user,
      application: application
    } do
      {:ok, user} = Accounts.update_user_preferences(user, %{time_zone: "America/New_York"})

      assert {:ok, interview} =
               Interviews.create_interview(user, application, %{
                 local_scheduled_at: "2026-03-10T14:30",
                 kind: "technical",
                 duration_minutes: 60
               })

      # New York is on daylight saving time (UTC-4) from March 8, 2026.
      assert interview.scheduled_at == ~U[2026-03-10 18:30:00Z]
    end

    test "requires a time and a type", %{user: user, application: application} do
      assert {:error, changeset} = Interviews.create_interview(user, application, %{})

      assert %{local_scheduled_at: ["can't be blank"], kind: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "validates the duration", %{user: user, application: application} do
      assert {:error, changeset} =
               Interviews.create_interview(user, application, %{
                 local_scheduled_at: "2026-03-10T14:30",
                 kind: "technical",
                 duration_minutes: 0
               })

      assert %{duration_minutes: [_]} = errors_on(changeset)
    end

    test "refuses another user's application", %{user: user} do
      other = application_fixture(user_fixture())

      assert_raise ArgumentError, fn ->
        Interviews.create_interview(user, other, %{
          local_scheduled_at: "2026-03-10T14:30",
          kind: "technical"
        })
      end
    end
  end

  test "change_interview/3 shows the stored time in the user's zone", %{
    user: user,
    application: application
  } do
    {:ok, user} = Accounts.update_user_preferences(user, %{time_zone: "Europe/Berlin"})

    interview =
      interview_fixture(user, application, %{local_scheduled_at: ~N[2026-01-15 09:00:00]})

    assert interview.scheduled_at == ~U[2026-01-15 08:00:00Z]
    changeset = Interviews.change_interview(user, interview)
    assert Ecto.Changeset.get_field(changeset, :local_scheduled_at) == ~N[2026-01-15 09:00:00]
  end

  test "update_interview/3 keeps the time unless it changes", %{
    user: user,
    application: application
  } do
    interview = interview_fixture(user, application)

    assert {:ok, updated} =
             Interviews.update_interview(user, interview, %{outcome: "passed", feedback: "Good"})

    assert updated.scheduled_at == interview.scheduled_at
    assert updated.outcome == :passed
  end

  describe "list_upcoming/2 and list_past/2" do
    test "split interviews around now", %{user: user, application: application} do
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      soon =
        interview_fixture(user, application, %{
          local_scheduled_at: NaiveDateTime.add(now, 2, :day)
        })

      later =
        interview_fixture(user, application, %{
          local_scheduled_at: NaiveDateTime.add(now, 10, :day)
        })

      past =
        interview_fixture(user, application, %{
          local_scheduled_at: NaiveDateTime.add(now, -2, :day)
        })

      assert Enum.map(Interviews.list_upcoming(user), & &1.id) == [soon.id, later.id]
      assert Enum.map(Interviews.list_upcoming(user, within_days: 7), & &1.id) == [soon.id]
      assert Enum.map(Interviews.list_past(user), & &1.id) == [past.id]
    end

    test "cancelled interviews are not upcoming", %{user: user, application: application} do
      interview_fixture(user, application, %{outcome: :cancelled})
      assert Interviews.list_upcoming(user) == []
    end

    test "only include the user's interviews", %{user: user} do
      other_user = user_fixture()
      interview_fixture(other_user, application_fixture(other_user))
      assert Interviews.list_upcoming(user) == []
    end
  end

  test "get_interview!/2 is scoped to the user", %{user: user} do
    other_user = user_fixture()
    interview = interview_fixture(other_user, application_fixture(other_user))
    assert_raise Ecto.NoResultsError, fn -> Interviews.get_interview!(user, interview.id) end
  end

  test "delete_interview/1", %{user: user, application: application} do
    interview = interview_fixture(user, application)
    assert {:ok, %Interview{}} = Interviews.delete_interview(interview)
    assert Interviews.list_upcoming(user) == []
  end

  test "kind_label/1" do
    assert Interview.kind_label(:phone_screen) == "Phone screen"
  end
end
