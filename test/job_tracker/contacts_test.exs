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

    test "requires a name", %{user: user} do
      assert {:error, changeset} = Contacts.create_contact(user, %{name: " "})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  test "update_contact/3 and delete_contact/1", %{user: user} do
    contact = contact_fixture(user)
    assert {:ok, contact} = Contacts.update_contact(user, contact, %{title: "Hiring manager"})
    assert contact.title == "Hiring manager"

    assert {:ok, _} = Contacts.delete_contact(contact)
    assert_raise Ecto.NoResultsError, fn -> Contacts.get_contact!(user, contact.id) end
  end
end
