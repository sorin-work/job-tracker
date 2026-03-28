defmodule JobTracker.DemoTest do
  use JobTracker.DataCase, async: true

  alias JobTracker.Accounts
  alias JobTracker.Demo
  alias JobTracker.{Interviews, Pipeline, Reminders}

  test "seed/0 creates the demo user with data, once" do
    assert {:ok, user} = Demo.seed()
    assert Accounts.get_user_by_email_and_password(Demo.email(), Demo.password())

    counts = Pipeline.count_by_status(user)
    assert counts |> Map.values() |> Enum.sum() > 30
    assert Enum.all?(JobTracker.Pipeline.Status.all(), &(counts[&1] > 0))

    assert Reminders.count_due(user) >= 3
    assert Interviews.list_upcoming(user, within_days: 7) != []
    assert JobTracker.Stats.summary(user).response_rate > 0

    assert {:error, :exists} = Demo.seed()
  end
end
