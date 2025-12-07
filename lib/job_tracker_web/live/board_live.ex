defmodule JobTrackerWeb.BoardLive do
  use JobTrackerWeb, :live_view

  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.Status

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Board")
     |> assign(:today, JobTracker.TimeZones.today(socket.assigns.current_user))
     |> load_board()}
  end

  defp load_board(socket) do
    assign(socket, :columns, Pipeline.board(socket.assigns.current_user))
  end

  @impl true
  def handle_event("move", %{"id" => id, "status" => status, "index" => index}, socket)
      when is_integer(index) do
    case Pipeline.move_application(socket.assigns.current_user, id, status, index) do
      {:ok, _application} ->
        {:noreply, load_board(socket)}

      {:error, _reason} ->
        {:noreply, socket |> put_flash(:error, "Could not move the application") |> load_board()}
    end
  end

  defp days_since(%DateTime{} = updated_at, today) do
    Date.diff(today, DateTime.to_date(updated_at))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Board
      <:subtitle>Drag cards between columns to change their status.</:subtitle>
    </.header>

    <div id="board" phx-hook="Board" class="mt-6 flex gap-3 overflow-x-auto pb-4">
      <section
        :for={status <- Status.all()}
        id={"column-#{status}"}
        data-status={status}
        class={[
          "flex w-64 shrink-0 flex-col rounded-lg bg-zinc-100/80 p-2",
          Status.closed?(status) && "opacity-90"
        ]}
      >
        <h2 class="flex items-center justify-between px-1 pb-2 text-sm font-semibold text-zinc-700">
          <.status_badge status={status} />
        </h2>
        <ol data-dropzone class="min-h-24 flex-1 space-y-2">
          <li
            :for={application <- @columns[status]}
            id={"card-#{application.id}"}
            data-id={application.id}
            draggable="true"
            class="rounded-md border border-zinc-200 bg-white p-3"
          >
            <.link navigate={~p"/applications/#{application}"} class="block">
              <p class="text-sm font-medium text-zinc-900">{application.title}</p>
              <p class="text-xs text-zinc-600">{application.company.name}</p>
            </.link>
            <div class="mt-2 flex items-center justify-end">
              <span class="text-[11px] text-zinc-400" title="Days since last change">
                {days_since(application.updated_at, @today)}d
              </span>
            </div>
          </li>
        </ol>
      </section>
    </div>
    """
  end
end
