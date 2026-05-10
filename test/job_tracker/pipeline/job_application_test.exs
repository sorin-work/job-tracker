defmodule JobTracker.Pipeline.JobApplicationTest do
  use JobTracker.DataCase, async: true

  alias JobTracker.Pipeline.JobApplication

  defp changeset(attrs) do
    JobApplication.changeset(
      %JobApplication{},
      Map.merge(%{title: "Engineer", company_id: 1}, attrs)
    )
  end

  test "valid with a title and a company" do
    assert changeset(%{}).valid?
  end

  test "needs a company id or a new company name" do
    changeset = JobApplication.changeset(%JobApplication{}, %{title: "Engineer"})
    assert %{company_id: ["pick a company or type a new name"]} = errors_on(changeset)

    assert JobApplication.changeset(%JobApplication{}, %{title: "Engineer", company_name: "Acme"}).valid?
  end

  test "salary max can't be below the min" do
    assert %{salary_max: ["must be greater than or equal to the minimum"]} =
             errors_on(changeset(%{salary_min: 120_000, salary_max: 100_000}))

    assert changeset(%{salary_min: 100_000, salary_max: 100_000}).valid?
    assert changeset(%{salary_max: 100_000}).valid?
  end

  test "salaries can't be negative" do
    assert %{salary_min: [_]} = errors_on(changeset(%{salary_min: -1}))
  end

  test "currency is upcased and must be three letters" do
    changeset = changeset(%{salary_currency: " eur "})
    assert Ecto.Changeset.get_change(changeset, :salary_currency) == "EUR"

    assert %{salary_currency: ["must be a 3 letter code like USD"]} =
             errors_on(changeset(%{salary_currency: "EURO"}))
  end

  test "posting url must be http or https" do
    assert %{posting_url: ["must be a valid URL"]} =
             errors_on(changeset(%{posting_url: "ftp://jobs.example.com"}))

    assert changeset(%{posting_url: "https://jobs.example.com/123"}).valid?

    assert Ecto.Changeset.get_change(
             changeset(%{posting_url: "jobs.example.com/1"}),
             :posting_url
           ) ==
             "https://jobs.example.com/1"
  end

  test "applied on can't be in the future" do
    future = Date.add(Date.utc_today(), 5)
    assert %{applied_on: ["can't be in the future"]} = errors_on(changeset(%{applied_on: future}))
    assert changeset(%{applied_on: Date.utc_today()}).valid?
  end

  test "rejects unknown statuses" do
    assert %{status: ["is invalid"]} = errors_on(changeset(%{status: "hired"}))
  end

  test "priority must be between 1 and 3" do
    assert %{priority: [_]} = errors_on(changeset(%{priority: 5}))
  end
end
