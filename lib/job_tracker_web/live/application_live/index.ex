defmodule JobTrackerWeb.ApplicationLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.JobApplication

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    applications = Pipeline.list_applications(socket.assigns.current_user)

    {:noreply,
     socket
     |> assign(:applications, applications)
     |> apply_action(socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    socket
    |> assign(:page_title, "New application")
    |> assign(:application, %JobApplication{tags: []})
  end

  defp apply_action(socket, :index) do
    socket
    |> assign(:page_title, "Applications")
    |> assign(:application, nil)
  end

  @impl true
  def handle_info({JobTrackerWeb.ApplicationLive.FormComponent, {:saved, _application}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Applications
      <:subtitle>
        {length(@applications)} {if length(@applications) == 1,
          do: "application",
          else: "applications"}
      </:subtitle>
      <:actions>
        <.link patch={~p"/applications/new"}>
          <.button>New application</.button>
        </.link>
      </:actions>
    </.header>

    <.empty_state :if={@applications == []} class="mt-8">
      Nothing here yet.
      <.link patch={~p"/applications/new"} class="font-medium text-brand">
        Add your first application
      </.link>
      or save one from a posting you liked.
    </.empty_state>

    <div
      :if={@applications != []}
      class="mt-6 overflow-x-auto rounded-lg border border-zinc-200 bg-white"
    >
      <table id="applications" class="w-full min-w-[48rem] text-left text-sm">
        <thead class="border-b border-zinc-200 bg-zinc-50 text-xs font-medium uppercase tracking-wide text-zinc-500">
          <tr>
            <th class="px-4 py-2">Role</th>
            <th class="px-4 py-2">Company</th>
            <th class="px-4 py-2">Status</th>
            <th class="px-4 py-2">Applied</th>
            <th class="px-4 py-2">Salary</th>
            <th class="px-4 py-2">Priority</th>
            <th class="px-4 py-2">Updated</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-zinc-100">
          <tr
            :for={application <- @applications}
            id={"application-#{application.id}"}
            class="hover:bg-zinc-50"
          >
            <td class="px-4 py-3">
              <.link
                navigate={~p"/applications/#{application}"}
                class="font-medium text-zinc-900 hover:underline"
              >
                {application.title}
              </.link>
              <.tag_list tags={application.tags} class="mt-1" />
            </td>
            <td class="px-4 py-3 text-zinc-700">{application.company.name}</td>
            <td class="px-4 py-3"><.status_badge status={application.status} /></td>
            <td class="px-4 py-3 text-zinc-700">{Format.short_date(application.applied_on)}</td>
            <td class="px-4 py-3 text-zinc-700">
              {Format.salary(
                application.salary_min,
                application.salary_max,
                application.salary_currency
              ) || "—"}
            </td>
            <td class="px-4 py-3"><.priority priority={application.priority} /></td>
            <td class="px-4 py-3 text-zinc-500">
              {Format.local_date(application.updated_at, @current_user)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <.modal
      :if={@live_action == :new}
      id="application-modal"
      show
      on_cancel={JS.patch(~p"/applications")}
    >
      <.live_component
        module={JobTrackerWeb.ApplicationLive.FormComponent}
        id={:new}
        title="New application"
        action={:new}
        application={@application}
        current_user={@current_user}
        patch={~p"/applications"}
      />
    </.modal>
    """
  end
end
