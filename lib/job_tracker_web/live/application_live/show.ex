defmodule JobTrackerWeb.ApplicationLive.Show do
  use JobTrackerWeb, :live_view

  alias JobTracker.Pipeline

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    application = Pipeline.get_application!(socket.assigns.current_user, id)

    {:noreply,
     socket
     |> assign_application(application)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp assign_application(socket, application) do
    socket
    |> assign(:application, application)
  end

  defp apply_action(socket, :show, _params) do
    assign(socket, :page_title, socket.assigns.application.title)
  end

  defp apply_action(socket, :edit, _params) do
    assign(socket, :page_title, "Edit #{socket.assigns.application.title}")
  end

  @impl true
  def handle_event("delete", _params, socket) do
    {:ok, _} = Pipeline.delete_application(socket.assigns.application)

    {:noreply,
     socket
     |> put_flash(:info, "Application deleted")
     |> push_navigate(to: ~p"/applications")}
  end

  @impl true
  def handle_info({_component, {:saved, _record}}, socket) do
    {:noreply, reload(socket)}
  end

  defp reload(socket) do
    application =
      Pipeline.get_application!(socket.assigns.current_user, socket.assigns.application.id)

    assign_application(socket, application)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.back navigate={~p"/applications"}>All applications</.back>

    <.header class="mt-6">
      {@application.title}
      <:subtitle>
        <.link
          navigate={~p"/companies/#{@application.company}"}
          class="font-medium text-zinc-700 hover:underline"
        >
          {@application.company.name}
        </.link>
        <span :if={@application.location}>· {@application.location}</span>
      </:subtitle>
      <:actions>
        <.link patch={~p"/applications/#{@application}/edit"}>
          <.button>Edit</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-3 flex flex-wrap items-center gap-3">
      <.status_badge status={@application.status} />
    </div>

    <div class="mt-8 grid gap-6 lg:grid-cols-3">
      <div class="space-y-6 lg:col-span-2">
        <.panel title="Details">
          <dl class="grid gap-4 text-sm sm:grid-cols-2">
            <div>
              <dt class="text-zinc-500">Applied on</dt>
              <dd class="mt-0.5 text-zinc-900">{Format.date(@application.applied_on)}</dd>
            </div>
            <div>
              <dt class="text-zinc-500">Salary</dt>
              <dd class="mt-0.5 text-zinc-900">
                {Format.salary(
                  @application.salary_min,
                  @application.salary_max,
                  @application.salary_currency
                ) ||
                  "Not listed"}
              </dd>
            </div>
            <div>
              <dt class="text-zinc-500">Job posting</dt>
              <dd class="mt-0.5 truncate">
                <a
                  :if={@application.posting_url}
                  href={@application.posting_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-brand hover:underline"
                >
                  {@application.posting_url}
                  <.icon name="hero-arrow-top-right-on-square-mini" class="h-4 w-4" />
                </a>
                <span :if={!@application.posting_url} class="text-zinc-900">—</span>
              </dd>
            </div>
          </dl>
          <div :if={@application.notes} class="mt-4 border-t border-zinc-100 pt-4">
            <p class="text-sm text-zinc-500">Notes</p>
            <p class="mt-1 whitespace-pre-line text-sm text-zinc-800">{@application.notes}</p>
          </div>
        </.panel>
      </div>

      <div class="space-y-6">
        <button
          type="button"
          phx-click="delete"
          data-confirm="Delete this application?"
          class="text-sm font-medium text-red-600 hover:text-red-800"
        >
          Delete application
        </button>
      </div>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="application-modal"
      show
      on_cancel={JS.patch(~p"/applications/#{@application}")}
    >
      <.live_component
        module={JobTrackerWeb.ApplicationLive.FormComponent}
        id={@application.id}
        title="Edit application"
        action={:edit}
        application={@application}
        current_user={@current_user}
        patch={~p"/applications/#{@application}"}
      />
    </.modal>
    """
  end
end
