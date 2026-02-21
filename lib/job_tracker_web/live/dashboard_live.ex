defmodule JobTrackerWeb.DashboardLive do
  use JobTrackerWeb, :live_view

  alias JobTracker.Interviews
  alias JobTracker.Interviews.Interview
  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.Status
  alias JobTracker.Reminders
  alias JobTracker.TimeZones
  alias JobTrackerWeb.Nav

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> load()}
  end

  defp load(socket) do
    user = socket.assigns.current_user

    socket
    |> assign(:today, TimeZones.today(user))
    |> assign(:counts, Pipeline.count_by_status(user))
    |> assign(:due, Reminders.list_due(user))
    |> assign(:upcoming, Interviews.list_upcoming(user, within_days: 7))
  end

  @impl true
  def handle_event("complete", %{"id" => id}, socket) do
    reminder = Reminders.get_reminder!(socket.assigns.current_user, id)
    {:ok, _} = Reminders.complete_reminder(reminder)

    {:noreply,
     socket
     |> put_flash(:info, "Done: #{reminder.title}")
     |> load()
     |> Nav.assign_due_count()}
  end

  def handle_event("snooze", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    reminder = Reminders.get_reminder!(user, id)
    {:ok, _} = Reminders.snooze_reminder(user, reminder, 1)

    {:noreply,
     socket
     |> load()
     |> Nav.assign_due_count()}
  end

  defp open_total(counts), do: counts |> Map.take(Status.open()) |> Map.values() |> Enum.sum()

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Dashboard
      <:subtitle>{Calendar.strftime(@today, "%A, %B %-d")}</:subtitle>
      <:actions>
        <.link navigate={~p"/applications/new"}>
          <.button>New application</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <.stat_card id="stat-open" title="Open applications" value={open_total(@counts)} />
      <.stat_card id="stat-interviewing" title="Interviewing" value={@counts.interviewing} />
      <.stat_card id="stat-offers" title="Offers" value={@counts.offer} />
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-2">
      <.panel id="due-reminders" title="Due today and overdue">
        <:actions>
          <.link navigate={~p"/reminders"} class="font-medium text-zinc-600 hover:text-zinc-900">
            All reminders
          </.link>
        </:actions>
        <.empty_state :if={@due == []}>Nothing due. Nice.</.empty_state>
        <ul class="divide-y divide-zinc-100">
          <li
            :for={reminder <- @due}
            id={"due-#{reminder.id}"}
            class="flex items-center justify-between gap-3 py-2"
          >
            <div class="min-w-0">
              <p class="truncate text-sm font-medium text-zinc-900">{reminder.title}</p>
              <p class="text-xs">
                <span class={
                  if Date.compare(reminder.due_on, @today) == :lt,
                    do: "text-red-600",
                    else: "text-amber-700"
                }>
                  {Format.due(reminder.due_on, @today)}
                </span>
                <.link
                  :if={reminder.job_application}
                  navigate={~p"/applications/#{reminder.job_application}"}
                  class="text-zinc-500 hover:underline"
                >
                  · {reminder.job_application.company.name}
                </.link>
              </p>
            </div>
            <div class="flex shrink-0 gap-2">
              <button
                phx-click="snooze"
                phx-value-id={reminder.id}
                class="rounded-md px-2 py-1 text-xs font-medium text-zinc-600 hover:bg-zinc-100"
              >
                Tomorrow
              </button>
              <button
                phx-click="complete"
                phx-value-id={reminder.id}
                class="rounded-md bg-zinc-900 px-2 py-1 text-xs font-medium text-white hover:bg-zinc-700"
              >
                Done
              </button>
            </div>
          </li>
        </ul>
      </.panel>

      <.panel id="upcoming-interviews" title="Interviews in the next 7 days">
        <:actions>
          <.link navigate={~p"/interviews"} class="font-medium text-zinc-600 hover:text-zinc-900">
            All interviews
          </.link>
        </:actions>
        <.empty_state :if={@upcoming == []}>No interviews coming up.</.empty_state>
        <ul class="divide-y divide-zinc-100">
          <li :for={interview <- @upcoming} class="py-2">
            <.link
              navigate={~p"/applications/#{interview.job_application}"}
              class="block hover:bg-zinc-50"
            >
              <p class="text-sm font-medium text-zinc-900">
                {Interview.kind_label(interview.kind)} · {interview.job_application.company.name}
              </p>
              <p class="text-xs text-zinc-500">
                {Format.datetime(interview.scheduled_at, @current_user)} · {interview.job_application.title}
              </p>
            </.link>
          </li>
        </ul>
      </.panel>
    </div>

    <.panel title="Pipeline" class="mt-6">
      <:actions>
        <.link navigate={~p"/board"} class="font-medium text-zinc-600 hover:text-zinc-900">
          Open board
        </.link>
      </:actions>
      <div class="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-8">
        <.link
          :for={status <- Status.all()}
          navigate={~p"/applications?status=#{status}"}
          class="rounded-md border border-zinc-100 p-3 text-center hover:bg-zinc-50"
        >
          <p class="text-xl font-semibold text-zinc-900">{@counts[status]}</p>
          <.status_badge status={status} class="mt-1" />
        </.link>
      </div>
    </.panel>
    """
  end
end
