defmodule JobTrackerWeb.CompanyLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.CompaniesFixtures

  setup :register_and_log_in_user

  test "lists and searches companies", %{conn: conn, user: user} do
    company_fixture(user, name: "Northwind")
    company_fixture(user, name: "Brightloop")

    {:ok, lv, html} = live(conn, ~p"/companies")
    assert html =~ "Northwind"
    assert html =~ "Brightloop"

    html = lv |> form("#company-search", search: "north") |> render_change()
    assert html =~ "Northwind"
    refute html =~ "Brightloop"
  end

  test "creates a company", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/companies/new")

    assert lv |> form("#company-form", company: %{name: "", website: "nope"}) |> render_change() =~
             "must be a valid URL"

    html =
      lv
      |> form("#company-form",
        company: %{name: "Initech", website: "https://initech.example.com"}
      )
      |> render_submit()

    assert_patch(lv, ~p"/companies")
    assert html =~ "Company saved"
    assert html =~ "Initech"
  end

  test "edits a company", %{conn: conn, user: user} do
    company = company_fixture(user, name: "Initech")
    {:ok, lv, _html} = live(conn, ~p"/companies/#{company}/edit")

    html = lv |> form("#company-form", company: %{industry: "Printers"}) |> render_submit()
    assert html =~ "Printers"
  end

  test "shows a company", %{conn: conn, user: user} do
    company = company_fixture(user, name: "Initech", notes: "Great snacks")

    {:ok, _lv, html} = live(conn, ~p"/companies/#{company}")
    assert html =~ "Great snacks"

    {:ok, lv, _html} = live(conn, ~p"/companies/#{company}/show/edit")
    html = lv |> form("#company-form", company: %{location: "Austin"}) |> render_submit()
    assert_patch(lv, ~p"/companies/#{company}")
    assert html =~ "Austin"
  end
end
