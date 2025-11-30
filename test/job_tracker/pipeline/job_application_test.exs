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

  test "currency must be three letters" do
    assert %{salary_currency: ["must be a 3 letter code like USD"]} =
             errors_on(changeset(%{salary_currency: "EURO"}))
  end

  test "posting url must be http or https" do
    assert %{posting_url: ["must be a valid URL"]} =
             errors_on(changeset(%{posting_url: "ftp://jobs.example.com"}))

    assert changeset(%{posting_url: "https://jobs.example.com/123"}).valid?
  end
end
