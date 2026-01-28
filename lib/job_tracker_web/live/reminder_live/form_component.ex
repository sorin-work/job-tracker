defmodule JobTrackerWeb.ReminderLive.FormComponent do
  use JobTrackerWeb, :live_component

  alias JobTracker.Pipeline
  alias JobTracker.Reminders

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Something to do by a certain day.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="reminder-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:title]}
          type="text"
          label="What"
          placeholder="Follow up with the recruiter"
        />
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:due_on]} type="date" label="Due on" />
          <.input
            :if={@application_options}
            field={@form[:job_application_id]}
            type="select"
            label="Application"
            prompt="None"
            options={@application_options}
          />
        </div>
        <div class="flex flex-wrap gap-2 text-xs">
          <span class="text-zinc-500">Quick pick:</span>
          <button
            :for={
              {label, days} <- [
                {"Tomorrow", 1},
                {"In 3 days", 3},
                {"In a week", 7},
                {"In two weeks", 14}
              ]
            }
            type="button"
            phx-click="quick_date"
            phx-value-days={days}
            phx-target={@myself}
            class="rounded-full border border-zinc-200 px-2 py-0.5 font-medium text-zinc-700 hover:bg-zinc-50"
          >
            {label}
          </button>
        </div>
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <:actions>
          <.button phx-disable-with="Saving...">Save reminder</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{reminder: reminder} = assigns, socket) do
    options =
      if assigns[:with_application_select] do
        assigns.current_user
        |> Pipeline.list_applications()
        |> Enum.map(&{"#{&1.title} · #{&1.company.name}", &1.id})
      end

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:application_options, options)
     |> assign_new(:form, fn -> to_form(Reminders.change_reminder(reminder)) end)}
  end

  @impl true
  def handle_event("validate", %{"reminder" => params}, socket) do
    changeset = Reminders.change_reminder(socket.assigns.reminder, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("quick_date", %{"days" => days}, socket) do
    due_on =
      Date.add(JobTracker.TimeZones.today(socket.assigns.current_user), String.to_integer(days))

    params = Map.put(socket.assigns.form.params, "due_on", Date.to_iso8601(due_on))
    changeset = Reminders.change_reminder(socket.assigns.reminder, params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"reminder" => params}, socket) do
    %{current_user: user, reminder: reminder} = socket.assigns

    # Reminders added from an application page are tied to it without a select.
    params =
      if reminder.job_application_id,
        do: Map.put_new(params, "job_application_id", reminder.job_application_id),
        else: params

    result =
      if reminder.id,
        do: Reminders.update_reminder(user, reminder, params),
        else: Reminders.create_reminder(user, params)

    case result do
      {:ok, reminder} ->
        send(self(), {__MODULE__, {:saved, reminder}})

        {:noreply,
         socket
         |> put_flash(:info, "Reminder saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
