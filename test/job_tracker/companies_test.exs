defmodule JobTracker.CompaniesTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.CompaniesFixtures

  alias JobTracker.Companies
  alias JobTracker.Companies.Company

  setup do
    %{user: user_fixture()}
  end

  describe "list_companies/2" do
    test "returns only the user's companies ordered by name", %{user: user} do
      company_fixture(user, name: "beta")
      company_fixture(user, name: "Alpha")
      company_fixture(user_fixture(), name: "Other")

      assert [%{name: "Alpha"}, %{name: "beta"}] = Companies.list_companies(user)
    end

    test "filters by name", %{user: user} do
      company_fixture(user, name: "Northwind")
      company_fixture(user, name: "Brightloop")

      assert [%{name: "Northwind"}] = Companies.list_companies(user, search: "north")
    end
  end

  describe "create_company/2" do
    test "creates a company", %{user: user} do
      assert {:ok, %Company{} = company} =
               Companies.create_company(user, %{name: "Acme", website: "https://acme.example.com"})

      assert company.name == "Acme"
    end

    test "requires a name", %{user: user} do
      assert {:error, changeset} = Companies.create_company(user, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "names are unique per user regardless of case", %{user: user} do
      company_fixture(user, name: "Acme")
      assert {:error, changeset} = Companies.create_company(user, %{name: "ACME"})
      assert %{name: ["you already have a company with this name"]} = errors_on(changeset)

      assert {:ok, _} = Companies.create_company(user_fixture(), %{name: "Acme"})
    end
  end

  test "delete_company/1 deletes the company", %{user: user} do
    company = company_fixture(user)
    assert {:ok, _} = Companies.delete_company(company)
    assert Companies.list_companies(user) == []
  end
end
