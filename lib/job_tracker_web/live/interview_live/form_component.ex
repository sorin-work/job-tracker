defmodule JobTrackerWeb.InterviewLive.FormComponent do
  use JobTrackerWeb, :live_component

  alias JobTracker.Interviews
  alias JobTracker.Interviews.Interview

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>
          {@application.title} at {@application.company.name}. Times are in {JobTracker.TimeZones.zone(
            @current_user
          )}.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="interview-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid gap-4 sm:grid-cols-3">
          <.input field={@form[:local_scheduled_at]} type="datetime-local" label="Date and time" />
          <.input
            field={@form[:duration_minutes]}
            type="number"
            label="Duration (minutes)"
            min="5"
            step="5"
          />
          <.input
            field={@form[:kind]}
            type="select"
            label="Type"
            prompt="Pick a type"
            options={kind_options()}
          />
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:location]} type="text" label="Location or meeting link" />
          <.input field={@form[:interviewers]} type="text" label="Interviewers" />
        </div>
        <.input
          field={@form[:prep_notes]}
          type="textarea"
          label="Prep notes"
          placeholder="Questions to ask, stories to tell, topics to review"
          rows="5"
        />
        <.input field={@form[:outcome]} type="select" label="Outcome" options={outcome_options()} />
        <.input
          field={@form[:feedback]}
          type="textarea"
          label="How it went"
          placeholder="Notes for yourself after the interview"
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save interview</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  defp kind_options, do: Enum.map(Interview.kinds(), &{Interview.kind_label(&1), &1})
  defp outcome_options, do: Enum.map(Interview.outcomes(), &{Format.label(&1), &1})

  @impl true
  def update(%{interview: interview} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Interviews.change_interview(assigns.current_user, interview))
     end)}
  end

  @impl true
  def handle_event("validate", %{"interview" => params}, socket) do
    changeset =
      Interviews.change_interview(socket.assigns.current_user, socket.assigns.interview, params)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"interview" => params}, socket) do
    %{current_user: user, interview: interview, application: application} = socket.assigns

    result =
      case socket.assigns.action do
        :new_interview -> Interviews.create_interview(user, application, params)
        :edit_interview -> Interviews.update_interview(user, interview, params)
      end

    case result do
      {:ok, interview} ->
        send(self(), {__MODULE__, {:saved, interview}})

        {:noreply,
         socket
         |> put_flash(:info, "Interview saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
