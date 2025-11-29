defmodule JobTrackerWeb.CompanyLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Companies
  alias JobTracker.Companies.Company

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :search, "")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> load()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp load(socket) do
    companies =
      Companies.list_companies(socket.assigns.current_user, search: socket.assigns.search)

    assign(socket, :companies, companies)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit company")
    |> assign(:company, Companies.get_company!(socket.assigns.current_user, id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New company")
    |> assign(:company, %Company{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Companies")
    |> assign(:company, nil)
  end

  @impl true
  def handle_info({JobTrackerWeb.CompanyLive.FormComponent, {:saved, _company}}, socket) do
    {:noreply, load(socket)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, socket |> assign(:search, search) |> load()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    company = Companies.get_company!(socket.assigns.current_user, id)

    {:ok, _} = Companies.delete_company(company)
    {:noreply, socket |> put_flash(:info, "Company deleted") |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Companies
      <:actions>
        <.link patch={~p"/companies/new"}>
          <.button>New company</.button>
        </.link>
      </:actions>
    </.header>

    <form id="company-search" phx-change="search" phx-submit="search" class="mt-6 max-w-sm">
      <input
        type="search"
        name="search"
        value={@search}
        placeholder="Search companies"
        phx-debounce="300"
        class="block w-full rounded-lg border-zinc-300 text-sm focus:border-zinc-400 focus:ring-0"
      />
    </form>

    <.empty_state :if={@companies == []} class="mt-6">
      {if @search == "", do: "No companies yet.", else: "No companies match your search."}
    </.empty_state>

    <.table
      :if={@companies != []}
      id="companies"
      rows={@companies}
      row_id={&"companies-#{&1.id}"}
      row_click={fn company -> JS.navigate(~p"/companies/#{company}") end}
    >
      <:col :let={company} label="Name">
        <span class="font-medium">{company.name}</span>
      </:col>
      <:col :let={company} label="Industry">{company.industry || "—"}</:col>
      <:col :let={company} label="Location">{company.location || "—"}</:col>
      <:action :let={company}>
        <.link patch={~p"/companies/#{company}/edit"}>Edit</.link>
      </:action>
      <:action :let={company}>
        <.link
          phx-click={JS.push("delete", value: %{id: company.id})}
          data-confirm="Delete this company?"
        >
          Delete
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="company-modal"
      show
      on_cancel={JS.patch(~p"/companies")}
    >
      <.live_component
        module={JobTrackerWeb.CompanyLive.FormComponent}
        id={@company.id || :new}
        title={@page_title}
        action={@live_action}
        company={@company}
        current_user={@current_user}
        patch={~p"/companies"}
      />
    </.modal>
    """
  end
end
