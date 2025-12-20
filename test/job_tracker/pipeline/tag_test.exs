defmodule JobTracker.Pipeline.TagTest do
  use ExUnit.Case, async: true

  alias JobTracker.Pipeline.Tag

  test "parse_names/1 splits, trims and dedupes" do
    assert Tag.parse_names(" remote, fintech ,remote,, ") == ["remote", "fintech"]
    assert Tag.parse_names("") == []
    assert Tag.parse_names(nil) == []
  end

  test "changeset trims the name and validates the color" do
    changeset = Tag.changeset(%Tag{}, %{name: " remote ", color: "sky"})
    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :name) == "remote"

    refute Tag.changeset(%Tag{}, %{name: "x", color: "chartreuse"}).valid?
  end
end
