defmodule JobTrackerWeb.ReminderLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Reminders
  alias JobTracker.Reminders.Reminder
  alias JobTracker.TimeZones
  alias JobTrackerWeb.Nav

  @impl true
  def mount(_params, _session, socket) do
    {:ok, load(socket)}
  end

  defp load(socket) do
    user = socket.assigns.current_user

    socket
    |> assign(:today, TimeZones.today(user))
    |> assign(:groups, Reminders.grouped(user))
    |> Nav.assign_due_count()
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Reminders")
    |> assign(:reminder, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New reminder")
    |> assign(:reminder, %Reminder{due_on: Date.add(socket.assigns.today, 1)})
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit reminder")
    |> assign(:reminder, Reminders.get_reminder!(socket.assigns.current_user, id))
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    reminder = Reminders.get_reminder!(socket.assigns.current_user, id)

    {:ok, _} =
      if Reminder.completed?(reminder),
        do: Reminders.reopen_reminder(reminder),
        else: Reminders.complete_reminder(reminder)

    {:noreply, load(socket)}
  end

  def handle_event("snooze", %{"id" => id, "days" => days}, socket) do
    user = socket.assigns.current_user
    reminder = Reminders.get_reminder!(user, id)
    {:ok, _} = Reminders.snooze_reminder(user, reminder, String.to_integer(days))
    {:noreply, load(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    reminder = Reminders.get_reminder!(socket.assigns.current_user, id)
    {:ok, _} = Reminders.delete_reminder(reminder)
    {:noreply, socket |> put_flash(:info, "Reminder deleted") |> load()}
  end

  @impl true
  def handle_info({JobTrackerWeb.ReminderLive.FormComponent, {:saved, _reminder}}, socket) do
    {:noreply, load(socket)}
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :reminders, :list, required: true
  attr :today, Date, required: true
  attr :tone, :string, default: "text-zinc-500"

  defp reminder_group(assigns) do
    ~H"""
    <section :if={@reminders != []} id={@id} class="mt-8">
      <h2 class="text-sm font-semibold text-zinc-900">
        {@title} <span class="font-normal text-zinc-500">({length(@reminders)})</span>
      </h2>
      <ul class="mt-3 divide-y divide-zinc-100 rounded-lg border border-zinc-200 bg-white">
        <li
          :for={reminder <- @reminders}
          id={"reminder-#{reminder.id}"}
          class="flex items-start gap-3 p-3"
        >
          <input
            type="checkbox"
            checked={Reminder.completed?(reminder)}
            phx-click="toggle"
            phx-value-id={reminder.id}
            class="mt-1 rounded border-zinc-300 text-zinc-900 focus:ring-0"
            aria-label={"Mark #{reminder.title} as done"}
          />
          <div class="min-w-0 flex-1">
            <p class={[
              "text-sm font-medium",
              Reminder.completed?(reminder) && "text-zinc-400 line-through"
            ]}>
              {reminder.title}
            </p>
            <p class="text-xs">
              <span class={@tone}>{Format.short_date(reminder.due_on)} · {Format.due(
                reminder.due_on,
                @today
              )}</span>
              <.link
                :if={reminder.job_application}
                navigate={~p"/applications/#{reminder.job_application}"}
                class="text-zinc-500 hover:underline"
              >
                · {reminder.job_application.title} at {reminder.job_application.company.name}
              </.link>
            </p>
            <p :if={reminder.notes} class="mt-1 whitespace-pre-line text-sm text-zinc-600">
              {reminder.notes}
            </p>
          </div>
          <div class="flex shrink-0 items-center gap-3 text-xs font-medium">
            <button
              :if={!Reminder.completed?(reminder)}
              phx-click="snooze"
              phx-value-id={reminder.id}
              phx-value-days="1"
              class="text-zinc-600 hover:text-zinc-900"
            >
              Snooze a day
            </button>
            <.link patch={~p"/reminders/#{reminder}/edit"} class="text-zinc-600 hover:text-zinc-900">Edit</.link>
            <button
              phx-click="delete"
              phx-value-id={reminder.id}
              data-confirm="Delete this reminder?"
              class="text-zinc-600 hover:text-red-600"
            >
              Delete
            </button>
          </div>
        </li>
      </ul>
    </section>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Reminders
      <:subtitle>Follow-ups and anything else you shouldn't forget.</:subtitle>
      <:actions>
        <.link patch={~p"/reminders/new"}>
          <.button>New reminder</.button>
        </.link>
      </:actions>
    </.header>

    <.empty_state
      :if={
        @groups.overdue == [] and @groups.today == [] and @groups.upcoming == [] and
          @groups.completed == []
      }
      class="mt-8"
    >
      No reminders yet. Add one here or from an application.
    </.empty_state>

    <.reminder_group
      id="overdue"
      title="Overdue"
      reminders={@groups.overdue}
      today={@today}
      tone="text-red-600"
    />
    <.reminder_group
      id="today"
      title="Due today"
      reminders={@groups.today}
      today={@today}
      tone="text-amber-700"
    />
    <.reminder_group id="upcoming" title="Upcoming" reminders={@groups.upcoming} today={@today} />
    <.reminder_group
      id="completed"
      title="Recently completed"
      reminders={@groups.completed}
      today={@today}
    />

    <.modal
      :if={@live_action in [:new, :edit]}
      id="reminder-modal"
      show
      on_cancel={JS.patch(~p"/reminders")}
    >
      <.live_component
        module={JobTrackerWeb.ReminderLive.FormComponent}
        id={@reminder.id || :new}
        title={@page_title}
        reminder={@reminder}
        current_user={@current_user}
        with_application_select
        patch={~p"/reminders"}
      />
    </.modal>
    """
  end
end
