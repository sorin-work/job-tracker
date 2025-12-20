defmodule JobTrackerWeb.ApplicationLive.FormComponent do
  use JobTrackerWeb, :live_component

  alias JobTracker.Companies
  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.{JobApplication, Status}

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>The role, where it came from and what it pays.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="application-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:title]}
          type="text"
          label="Job title"
          placeholder="Senior Backend Engineer"
        />
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@form[:company_id]}
            type="select"
            label="Company"
            prompt="Pick a company"
            options={@company_options}
          />
          <.input
            field={@form[:company_name]}
            type="text"
            label="Or add a new company"
            placeholder="Company name"
          />
        </div>
        <div class="grid gap-4 sm:grid-cols-3">
          <.input field={@form[:status]} type="select" label="Status" options={Status.options()} />
          <.input
            field={@form[:priority]}
            type="select"
            label="Priority"
            options={[{"Low", 1}, {"Medium", 2}, {"High", 3}]}
          />
          <.input field={@form[:applied_on]} type="date" label="Applied on" />
        </div>
        <div class="grid gap-4 sm:grid-cols-3">
          <.input field={@form[:location]} type="text" label="Location" />
          <.input
            field={@form[:work_mode]}
            type="select"
            label="Work mode"
            prompt="Not specified"
            options={label_options(JobApplication.work_modes())}
          />
          <.input
            field={@form[:source]}
            type="select"
            label="Source"
            prompt="Not specified"
            options={label_options(JobApplication.sources())}
          />
        </div>
        <div class="grid gap-4 sm:grid-cols-3">
          <.input field={@form[:salary_min]} type="number" label="Salary from" min="0" step="1000" />
          <.input field={@form[:salary_max]} type="number" label="Salary to" min="0" step="1000" />
          <.input field={@form[:salary_currency]} type="text" label="Currency" maxlength="3" />
        </div>
        <.input
          field={@form[:posting_url]}
          type="url"
          label="Job posting URL"
          placeholder="https://"
        />
        <.input
          field={@form[:tag_names]}
          type="text"
          label="Tags"
          placeholder="remote, fintech, referral"
        />
        <.input
          field={@form[:description]}
          type="textarea"
          label="Job description"
          placeholder="Paste the posting here, it may be gone by the time you interview"
          rows="6"
        />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <:actions>
          <.button phx-disable-with="Saving...">Save application</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  defp label_options(values), do: Enum.map(values, &{Format.label(&1), &1})

  @impl true
  def update(%{application: application} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:company_options, Companies.company_options(assigns.current_user))
     |> assign_new(:form, fn -> to_form(Pipeline.change_application(application)) end)}
  end

  @impl true
  def handle_event("validate", %{"job_application" => params}, socket) do
    changeset = Pipeline.change_application(socket.assigns.application, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"job_application" => params}, socket) do
    save_application(socket, socket.assigns.action, params)
  end

  defp save_application(socket, :edit, params) do
    user = socket.assigns.current_user

    case Pipeline.update_application(user, socket.assigns.application, params) do
      {:ok, application} ->
        notify_parent({:saved, application})

        {:noreply,
         socket
         |> put_flash(:info, "Application updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_application(socket, :new, params) do
    case Pipeline.create_application(socket.assigns.current_user, params) do
      {:ok, application} ->
        notify_parent({:saved, application})

        {:noreply,
         socket
         |> put_flash(:info, "Application added")
         |> push_navigate(to: ~p"/applications/#{application}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
