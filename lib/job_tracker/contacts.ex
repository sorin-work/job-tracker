defmodule JobTracker.Contacts do
  @moduledoc """
  People met along the way: recruiters, hiring managers, referrals.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts.User
  alias JobTracker.Companies
  alias JobTracker.Companies.Company
  alias JobTracker.Contacts.Contact
  alias JobTracker.Repo

  @doc """
  Lists the user's contacts ordered by name.

  ## Options

    * `:company_id` - only contacts at this company
    * `:search` - text to look for in the name, title, email and company name
  """
  def list_contacts(%User{id: user_id}, opts \\ []) do
    Contact
    |> where(user_id: ^user_id)
    |> join(:left, [c], co in assoc(c, :company), as: :company)
    |> filter_company(opts[:company_id])
    |> filter_search(opts[:search])
    |> order_by([c], asc: c.name)
    |> preload([company: co], company: co)
    |> Repo.all()
  end

  defp filter_company(query, nil), do: query
  defp filter_company(query, id), do: where(query, [c], c.company_id == ^id)

  defp filter_search(query, search) when is_binary(search) and search != "" do
    pattern = "%" <> Companies.escape_like(String.trim(search)) <> "%"

    where(
      query,
      [c, company: co],
      ilike(c.name, ^pattern) or ilike(c.title, ^pattern) or ilike(c.email, ^pattern) or
        ilike(co.name, ^pattern)
    )
  end

  defp filter_search(query, _search), do: query

  def get_contact!(%User{id: user_id}, id) do
    Contact
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload(:company)
  end

  def create_contact(%User{} = user, attrs) do
    %Contact{user_id: user.id}
    |> Contact.changeset(attrs)
    |> validate_company_owner(user)
    |> Repo.insert()
  end

  def update_contact(%User{} = user, %Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> validate_company_owner(user)
    |> Repo.update()
  end

  defp validate_company_owner(changeset, user) do
    case Ecto.Changeset.get_change(changeset, :company_id) do
      nil ->
        changeset

      id ->
        if Repo.exists?(from c in Company, where: c.id == ^id and c.user_id == ^user.id) do
          changeset
        else
          Ecto.Changeset.add_error(changeset, :company_id, "is not valid")
        end
    end
  end

  def delete_contact(%Contact{} = contact), do: Repo.delete(contact)

  def change_contact(%Contact{} = contact, attrs \\ %{}), do: Contact.changeset(contact, attrs)
end
