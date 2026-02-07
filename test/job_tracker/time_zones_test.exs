defmodule JobTracker.TimeZonesTest do
  use ExUnit.Case, async: true

  alias JobTracker.Accounts.User
  alias JobTracker.TimeZones

  test "from_local/2 converts wall-clock time to UTC" do
    assert TimeZones.from_local(~N[2026-07-01 09:00:00], "Europe/London") ==
             ~U[2026-07-01 08:00:00Z]

    assert TimeZones.from_local(~N[2026-01-01 09:00:00], "Europe/London") ==
             ~U[2026-01-01 09:00:00Z]
  end

  test "to_local/2 shifts into the user's zone" do
    user = %User{time_zone: "Asia/Tokyo"}
    local = TimeZones.to_local(~U[2026-05-01 23:00:00Z], user)
    assert local.hour == 8
    assert local.day == 2
  end
end
