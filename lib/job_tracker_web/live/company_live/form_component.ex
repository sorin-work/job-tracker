defmodule JobTrackerWeb.CompanyLive.FormComponent do
  use JobTrackerWeb, :live_component

  alias JobTracker.Companies

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>{@title}</.header>

      <.simple_form
        for={@form}
        id="company-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:website]} type="url" label="Website" placeholder="https://" />
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:industry]} type="text" label="Industry" />
          <.input field={@form[:location]} type="text" label="Location" />
        </div>
        <.input
          field={@form[:notes]}
          type="textarea"
          label="Notes"
          placeholder="Culture, interview process, what you've heard"
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save company</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{company: company} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(Companies.change_company(company)) end)}
  end

  @impl true
  def handle_event("validate", %{"company" => params}, socket) do
    changeset = Companies.change_company(socket.assigns.company, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"company" => params}, socket) do
    result =
      case socket.assigns.action do
        :edit -> Companies.update_company(socket.assigns.company, params)
        :new -> Companies.create_company(socket.assigns.current_user, params)
      end

    case result do
      {:ok, company} ->
        send(self(), {__MODULE__, {:saved, company}})

        {:noreply,
         socket
         |> put_flash(:info, "Company saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
