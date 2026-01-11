defmodule JobTracker.ValidationTest do
  use ExUnit.Case, async: true

  import Ecto.Changeset

  alias JobTracker.Validation

  defp changeset(attrs) do
    cast({%{}, %{url: :string, name: :string}}, attrs, [:url, :name])
  end

  test "validate_url/2 accepts http and https urls" do
    assert changeset(%{url: "https://example.com/jobs?id=1"})
           |> Validation.validate_url(:url)
           |> Map.get(:valid?)

    assert changeset(%{url: "http://jobs.example.co.uk"})
           |> Validation.validate_url(:url)
           |> Map.get(:valid?)
  end

  test "validate_url/2 adds https:// when the scheme is missing" do
    changeset = changeset(%{url: " example.com/careers "}) |> Validation.validate_url(:url)
    assert get_change(changeset, :url) == "https://example.com/careers"
  end

  test "validate_url/2 rejects other schemes and hosts without a dot" do
    refute changeset(%{url: "javascript:alert(1)"})
           |> Validation.validate_url(:url)
           |> Map.get(:valid?)

    refute changeset(%{url: "mailto://someone"})
           |> Validation.validate_url(:url)
           |> Map.get(:valid?)

    refute changeset(%{url: "https://localhost"})
           |> Validation.validate_url(:url)
           |> Map.get(:valid?)
  end

  test "trim_fields/2 trims and turns blanks into nil" do
    changeset = changeset(%{name: "  Acme  "}) |> Validation.trim_fields([:name])
    assert get_change(changeset, :name) == "Acme"

    changeset = changeset(%{name: "   "}) |> Validation.trim_fields([:name])
    assert get_field(changeset, :name) == nil
  end
end
