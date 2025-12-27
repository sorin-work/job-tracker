defmodule JobTracker.Pipeline.TagTest do
  use ExUnit.Case, async: true

  alias JobTracker.Pipeline.Tag

  test "parse_names/1 splits, normalizes and dedupes" do
    assert Tag.parse_names(" Remote, fintech ,remote,, Dream   Job ") == [
             "remote",
             "fintech",
             "dream job"
           ]

    assert Tag.parse_names("") == []
    assert Tag.parse_names(nil) == []
  end

  test "changeset normalizes the name and validates the color" do
    changeset = Tag.changeset(%Tag{}, %{name: " Remote ", color: "sky"})
    assert changeset.valid?
    assert Ecto.Changeset.get_change(changeset, :name) == "remote"

    refute Tag.changeset(%Tag{}, %{name: "x", color: "chartreuse"}).valid?
  end
end
