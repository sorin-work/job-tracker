defmodule JobTrackerWeb.FormatTest do
  use ExUnit.Case, async: true

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

  test "label/1" do
    assert Format.label(:company_site) == "Company site"
    assert Format.label(nil) == "—"
  end
end
