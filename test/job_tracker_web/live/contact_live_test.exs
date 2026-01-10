defmodule JobTrackerWeb.ContactLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.ActivityFixtures
  import JobTracker.CompaniesFixtures

  setup :register_and_log_in_user

  test "lists and searches contacts", %{conn: conn, user: user} do
    contact_fixture(user, name: "Priya Raman")
    contact_fixture(user, name: "Tom Becker")

    {:ok, lv, html} = live(conn, ~p"/contacts")
    assert html =~ "Priya Raman"

    html = lv |> form("#contact-search", search: "tom") |> render_change()
    assert html =~ "Tom Becker"
    refute html =~ "Priya Raman"
  end

  test "creates a contact for a company picked from the link", %{conn: conn, user: user} do
    company = company_fixture(user, name: "Initech")
    {:ok, lv, _html} = live(conn, ~p"/contacts/new?company_id=#{company.id}")

    assert lv |> form("#contact-form", contact: %{name: "Bill", email: "bill"}) |> render_change() =~
             "must be a valid email address"

    html =
      lv
      |> form("#contact-form",
        contact: %{name: "Bill Lumbergh", email: "bill@initech.example.com"}
      )
      |> render_submit()

    assert_patch(lv, ~p"/contacts")
    assert html =~ "Bill Lumbergh"
    assert html =~ "Initech"
  end
end
