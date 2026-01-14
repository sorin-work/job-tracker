defmodule JobTracker.ContactsTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.ActivityFixtures
  import JobTracker.CompaniesFixtures

  alias JobTracker.Contacts

  setup do
    %{user: user_fixture()}
  end

  test "list_contacts/2 returns the user's contacts by name with their company", %{user: user} do
    company = company_fixture(user, name: "Acme")
    contact_fixture(user, name: "zoe", company_id: company.id)
    contact_fixture(user, name: "Adam")
    contact_fixture(user_fixture(), name: "Someone else")

    assert [%{name: "Adam", company: nil}, %{name: "zoe", company: %{name: "Acme"}}] =
             Contacts.list_contacts(user)
  end

  test "list_contacts/2 filters by company and search text", %{user: user} do
    company = company_fixture(user, name: "Acme")
    contact_fixture(user, name: "Priya", company_id: company.id)
    contact_fixture(user, name: "Tom", title: "Engineering Manager")

    assert [%{name: "Priya"}] = Contacts.list_contacts(user, company_id: company.id)
    assert [%{name: "Priya"}] = Contacts.list_contacts(user, search: "acme")
    assert [%{name: "Tom"}] = Contacts.list_contacts(user, search: "manager")
  end

  describe "create_contact/2" do
    test "validates email, phone and linkedin url", %{user: user} do
      assert {:error, changeset} =
               Contacts.create_contact(user, %{
                 name: "Jane",
                 email: "jane",
                 phone: "call me",
                 linkedin_url: "not a url"
               })

      assert %{email: [_], phone: [_], linkedin_url: [_]} = errors_on(changeset)
    end

    test "accepts common phone formats", %{user: user} do
      assert {:ok, _} = Contacts.create_contact(user, %{name: "Jane", phone: "+1 (555) 123-4567"})
    end

    test "requires a name", %{user: user} do
      assert {:error, changeset} = Contacts.create_contact(user, %{name: " "})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects another user's company", %{user: user} do
      company = company_fixture(user_fixture())

      assert {:error, changeset} =
               Contacts.create_contact(user, %{name: "Jane", company_id: company.id})

      assert %{company_id: ["is not valid"]} = errors_on(changeset)
    end
  end

  test "update_contact/3 and delete_contact/1", %{user: user} do
    contact = contact_fixture(user)
    assert {:ok, contact} = Contacts.update_contact(user, contact, %{title: "Hiring manager"})
    assert contact.title == "Hiring manager"

    assert {:ok, _} = Contacts.delete_contact(contact)
    assert_raise Ecto.NoResultsError, fn -> Contacts.get_contact!(user, contact.id) end
  end

  test "deleting a company keeps its contacts", %{user: user} do
    company = company_fixture(user)
    contact = contact_fixture(user, company_id: company.id)

    {:ok, _} = JobTracker.Companies.delete_company(company)
    assert Contacts.get_contact!(user, contact.id).company_id == nil
  end
end
