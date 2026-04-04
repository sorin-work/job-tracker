defmodule JobTracker.ExportTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.CompaniesFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Export

  test "applications_csv/1 exports one row per application" do
    user = user_fixture()
    company = company_fixture(user, name: "Acme, Inc.")

    application_fixture(user,
      title: "Engineer",
      company_id: company.id,
      status: :applied,
      salary_min: 100_000,
      tag_names: "remote, fintech",
      notes: "said \"call me\""
    )

    application_fixture(user_fixture(), title: "Not mine")

    [header, row] =
      user
      |> Export.applications_csv()
      |> IO.iodata_to_binary()
      |> String.split("\r\n", trim: true)

    assert header =~ "Title,Company,Status,Applied on"
    assert row =~ ~s(Engineer,"Acme, Inc.",Applied,)
    assert row =~ ~s(100000,,USD,"fintech, remote")
    assert row =~ ~s("said ""call me""")
  end

  test "encode_field/1 quotes fields when needed" do
    assert Export.encode_field("plain") == "plain"
    assert Export.encode_field("a, b") == ~s("a, b")
    assert Export.encode_field(nil) == ""
    assert Export.encode_field(12) == "12"
  end
end
