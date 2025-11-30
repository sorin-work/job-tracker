defmodule JobTrackerWeb.CompanyLive.Show do
  use JobTrackerWeb, :live_view

  alias JobTracker.Companies
  alias JobTracker.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    {:noreply,
     socket
     |> load(id)
     |> assign(:page_title, page_title(socket.assigns.live_action))}
  end

  defp load(socket, id) do
    user = socket.assigns.current_user
    company = Companies.get_company!(user, id)

    socket
    |> assign(:company, company)
    |> assign(:applications, Pipeline.list_applications(user, company_id: company.id))
  end

  @impl true
  def handle_info({JobTrackerWeb.CompanyLive.FormComponent, {:saved, company}}, socket) do
    {:noreply, load(socket, company.id)}
  end

  defp page_title(:show), do: "Company"
  defp page_title(:edit), do: "Edit company"

  @impl true
  def render(assigns) do
    ~H"""
    <.back navigate={~p"/companies"}>All companies</.back>

    <.header class="mt-6">
      {@company.name}
      <:subtitle>
        {[@company.industry, @company.location] |> Enum.reject(&is_nil/1) |> Enum.join(" · ")}
      </:subtitle>
      <:actions>
        <.link patch={~p"/companies/#{@company}/show/edit"} phx-click={JS.push_focus()}>
          <.button>Edit</.button>
        </.link>
      </:actions>
    </.header>

    <p :if={@company.website} class="mt-2 text-sm">
      <a
        href={@company.website}
        target="_blank"
        rel="noopener noreferrer"
        class="text-brand hover:underline"
      >
        {@company.website}
      </a>
    </p>
    <p :if={@company.notes} class="mt-4 whitespace-pre-line text-sm text-zinc-700">
      {@company.notes}
    </p>

    <div class="mt-8 grid gap-6 lg:grid-cols-3">
      <.panel id="company-applications" title="Applications" class="lg:col-span-2">
        <:actions>
          <.link navigate={~p"/applications/new"} class="font-medium text-brand">Add</.link>
        </:actions>
        <.empty_state :if={@applications == []}>No applications at {@company.name} yet.</.empty_state>
        <ul class="divide-y divide-zinc-100">
          <li :for={application <- @applications} class="flex items-center justify-between gap-3 py-2">
            <.link
              navigate={~p"/applications/#{application}"}
              class="text-sm font-medium text-zinc-900 hover:underline"
            >
              {application.title}
            </.link>
            <.status_badge status={application.status} />
          </li>
        </ul>
      </.panel>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="company-modal"
      show
      on_cancel={JS.patch(~p"/companies/#{@company}")}
    >
      <.live_component
        module={JobTrackerWeb.CompanyLive.FormComponent}
        id={@company.id}
        title={@page_title}
        action={@live_action}
        company={@company}
        current_user={@current_user}
        patch={~p"/companies/#{@company}"}
      />
    </.modal>
    """
  end
end
