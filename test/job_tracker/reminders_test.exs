defmodule JobTracker.RemindersTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.ActivityFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Reminders

  setup do
    %{user: user_fixture()}
  end

  defp days(n), do: Date.add(Date.utc_today(), n)

  test "list_due/1 returns open reminders due today or earlier", %{user: user} do
    overdue = reminder_fixture(user, due_on: days(-2))
    today = reminder_fixture(user, due_on: days(0))
    _later = reminder_fixture(user, due_on: days(3))
    done = reminder_fixture(user, due_on: days(-1))
    {:ok, _} = Reminders.complete_reminder(done)
    reminder_fixture(user_fixture(), due_on: days(-1))

    assert Enum.map(Reminders.list_due(user), & &1.id) == [overdue.id, today.id]
    assert Reminders.count_due(user) == 2
  end

  test "grouped/1 splits reminders into overdue, today, upcoming and completed", %{user: user} do
    overdue = reminder_fixture(user, due_on: days(-1))
    today = reminder_fixture(user, due_on: days(0))
    upcoming = reminder_fixture(user, due_on: days(4))
    {:ok, done} = user |> reminder_fixture(due_on: days(-3)) |> Reminders.complete_reminder()

    groups = Reminders.grouped(user)
    assert Enum.map(groups.overdue, & &1.id) == [overdue.id]
    assert Enum.map(groups.today, & &1.id) == [today.id]
    assert Enum.map(groups.upcoming, & &1.id) == [upcoming.id]
    assert Enum.map(groups.completed, & &1.id) == [done.id]
  end

  describe "create_reminder/2" do
    test "requires a title and a due date", %{user: user} do
      assert {:error, changeset} = Reminders.create_reminder(user, %{title: ""})
      assert %{title: ["can't be blank"], due_on: ["can't be blank"]} = errors_on(changeset)
    end

    test "can be attached to the user's application", %{user: user} do
      application = application_fixture(user)
      reminder = reminder_fixture(user, job_application_id: application.id)
      assert reminder.job_application_id == application.id
    end
  end

  test "update_reminder/3 and delete_reminder/1", %{user: user} do
    reminder = reminder_fixture(user)
    assert {:ok, reminder} = Reminders.update_reminder(user, reminder, %{title: "Call back"})
    assert reminder.title == "Call back"
    assert {:ok, _} = Reminders.delete_reminder(reminder)
    assert Reminders.list_due(user) == []
  end
end
