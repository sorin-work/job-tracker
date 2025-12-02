defmodule JobTracker.CompaniesTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.CompaniesFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Companies
  alias JobTracker.Companies.Company

  setup do
    %{user: user_fixture()}
  end

  describe "list_companies/2" do
    test "returns only the user's companies, ordered by name, with application counts", %{
      user: user
    } do
      beta = company_fixture(user, name: "beta")
      alpha = company_fixture(user, name: "Alpha")
      company_fixture(user_fixture(), name: "Other")
      application_fixture(user, company_id: beta.id)
      application_fixture(user, company_id: beta.id)

      assert [%{id: alpha_id, application_count: 0}, %{id: beta_id, application_count: 2}] =
               Companies.list_companies(user)

      assert alpha_id == alpha.id
      assert beta_id == beta.id
    end

    test "filters by name", %{user: user} do
      company_fixture(user, name: "Northwind")
      company_fixture(user, name: "Brightloop")

      assert [%{name: "Northwind"}] = Companies.list_companies(user, search: "north")
    end

    test "treats LIKE wildcards in the search literally", %{user: user} do
      company_fixture(user, name: "100% Remote")
      company_fixture(user, name: "Ten Remote")

      assert [%{name: "100% Remote"}] = Companies.list_companies(user, search: "%")
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

  describe "find_or_create_company/2" do
    test "creates a missing company", %{user: user} do
      assert {:ok, %Company{name: "Initech"}} = Companies.find_or_create_company(user, "Initech")
    end
  end

  describe "delete_company/1" do
    test "deletes a company without applications", %{user: user} do
      company = company_fixture(user)
      assert {:ok, _} = Companies.delete_company(company)
      assert Companies.list_companies(user) == []
    end

    test "refuses to delete a company that has applications", %{user: user} do
      company = company_fixture(user)
      application_fixture(user, company_id: company.id)
      assert {:error, :has_applications} = Companies.delete_company(company)
    end
  end

  test "company_options/1 returns name and id pairs", %{user: user} do
    company = company_fixture(user, name: "Acme")
    assert Companies.company_options(user) == [{"Acme", company.id}]
  end
end
