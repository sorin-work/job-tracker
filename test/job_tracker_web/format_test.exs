defmodule JobTrackerWeb.FormatTest do
  use ExUnit.Case, async: true

  alias JobTracker.Accounts.User
  alias JobTrackerWeb.Format

  test "salary/3 formats ranges compactly" do
    assert Format.salary(120_000, 140_000, "USD") == "$120k – $140k"
    assert Format.salary(60_500, nil, "EUR") == "from €60.5k"
    assert Format.salary(nil, 80_000, "GBP") == "up to £80k"
    assert Format.salary(90_000, 90_000, "USD") == "$90k"
    assert Format.salary(1_200_000, nil, "JPY") == "from ¥1.2M"
    assert Format.salary(50, 80, "CHF") == "50 CHF – 80 CHF"
    assert Format.salary(nil, nil, "USD") == nil
  end

  test "due/2 describes how far away a date is" do
    today = ~D[2026-03-10]
    assert Format.due(today, today) == "today"
    assert Format.due(~D[2026-03-11], today) == "tomorrow"
    assert Format.due(~D[2026-03-09], today) == "yesterday"
    assert Format.due(~D[2026-03-15], today) == "in 5 days"
    assert Format.due(~D[2026-03-06], today) == "4 days overdue"
  end

  test "datetime/2 uses the user's time zone" do
    user = %User{time_zone: "America/Chicago"}
    assert Format.datetime(~U[2026-03-03 20:30:00Z], user) == "Tue, Mar 3 · 2:30 PM"
  end

  test "date helpers" do
    assert Format.date(~D[2026-03-04]) == "Mar 4, 2026"
    assert Format.short_date(~D[2026-03-04]) == "Mar 4"
    assert Format.date(nil) == "—"
  end

  test "percent/1 and label/1" do
    assert Format.percent(50.0) == "50%"
    assert Format.percent(33.3) == "33.3%"
    assert Format.percent(nil) == "—"
    assert Format.label(:company_site) == "Company site"
  end
end
