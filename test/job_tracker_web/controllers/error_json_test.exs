defmodule JobTrackerWeb.ErrorJSONTest do
  use JobTrackerWeb.ConnCase, async: true

  test "renders 404" do
    assert JobTrackerWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert JobTrackerWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
