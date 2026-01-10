defmodule JobTrackerWeb.ContactLive.FormComponent do
  use JobTrackerWeb, :live_component

  alias JobTracker.Companies
  alias JobTracker.Contacts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>{@title}</.header>

      <.simple_form
        for={@form}
        id="contact-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:name]} type="text" label="Name" />
          <.input
            field={@form[:title]}
            type="text"
            label="Title"
            placeholder="Recruiter, hiring manager…"
          />
        </div>
        <.input
          field={@form[:company_id]}
          type="select"
          label="Company"
          prompt="No company"
          options={@company_options}
        />
        <div class="grid gap-4 sm:grid-cols-2">
          <.input field={@form[:email]} type="email" label="Email" />
          <.input field={@form[:phone]} type="tel" label="Phone" />
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <.input
            field={@form[:linkedin_url]}
            type="url"
            label="LinkedIn"
            placeholder="https://www.linkedin.com/in/…"
          />
          <.input field={@form[:last_contacted_on]} type="date" label="Last contacted" />
        </div>
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <:actions>
          <.button phx-disable-with="Saving...">Save contact</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{contact: contact} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:company_options, Companies.company_options(assigns.current_user))
     |> assign_new(:form, fn -> to_form(Contacts.change_contact(contact)) end)}
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    changeset = Contacts.change_contact(socket.assigns.contact, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"contact" => params}, socket) do
    user = socket.assigns.current_user

    result =
      case socket.assigns.action do
        :edit -> Contacts.update_contact(user, socket.assigns.contact, params)
        :new -> Contacts.create_contact(user, params)
      end

    case result do
      {:ok, contact} ->
        send(self(), {__MODULE__, {:saved, contact}})

        {:noreply,
         socket
         |> put_flash(:info, "Contact saved")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
