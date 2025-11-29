defmodule JobTracker.CompaniesFixtures do
  @moduledoc """
  Test helpers for creating companies.
  """

  def company_fixture(user, attrs \\ %{}) do
    {:ok, company} =
      JobTracker.Companies.create_company(
        user,
        Enum.into(attrs, %{
          name: "Company #{System.unique_integer([:positive])}",
          website: "https://example.com",
          industry: "Software",
          location: "Remote"
        })
      )

    company
  end
end
