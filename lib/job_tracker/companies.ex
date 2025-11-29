defmodule JobTracker.Companies do
  @moduledoc """
  Companies a user is applying to. Every function is scoped to a user.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts.User
  alias JobTracker.Companies.Company
  alias JobTracker.Repo

  @doc """
  Lists the user's companies ordered by name.

  ## Options

    * `:search` - only companies whose name contains the given text
  """
  def list_companies(%User{id: user_id}, opts \\ []) do
    Company
    |> where(user_id: ^user_id)
    |> filter_search(opts[:search])
    |> order_by([c], asc: fragment("lower(?)", c.name))
    |> Repo.all()
  end

  defp filter_search(query, search) when is_binary(search) and search != "" do
    pattern = "%" <> search <> "%"
    where(query, [c], ilike(c.name, ^pattern))
  end

  defp filter_search(query, _search), do: query

  @doc """
  Gets one of the user's companies. Raises `Ecto.NoResultsError` if it does not
  exist or belongs to someone else.
  """
  def get_company!(%User{id: user_id}, id) do
    Repo.get_by!(Company, id: id, user_id: user_id)
  end

  def create_company(%User{} = user, attrs) do
    %Company{user_id: user.id}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end

  def update_company(%Company{} = company, attrs) do
    company
    |> Company.changeset(attrs)
    |> Repo.update()
  end

  def delete_company(%Company{} = company) do
    Repo.delete(company)
  end

  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end
end
