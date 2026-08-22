defmodule JobTrackerWeb.ContactLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Contacts
  alias JobTracker.Contacts.Contact

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :search, "")}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> load()
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp load(socket) do
    assign(
      socket,
      :contacts,
      Contacts.list_contacts(socket.assigns.current_user, search: socket.assigns.search)
    )
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit contact")
    |> assign(:contact, Contacts.get_contact!(socket.assigns.current_user, id))
  end

  defp apply_action(socket, :new, params) do
    company_id =
      case Integer.parse(params["company_id"] || "") do
        {id, ""} -> id
        _ -> nil
      end

    socket
    |> assign(:page_title, "New contact")
    |> assign(:contact, %Contact{company_id: company_id})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Contacts")
    |> assign(:contact, nil)
  end

  @impl true
  def handle_info({JobTrackerWeb.ContactLive.FormComponent, {:saved, _contact}}, socket) do
    {:noreply, load(socket)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, socket |> assign(:search, search) |> load()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    contact = Contacts.get_contact!(socket.assigns.current_user, id)
    {:ok, _} = Contacts.delete_contact(contact)
    {:noreply, socket |> put_flash(:info, "Contact deleted") |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Contacts
      <:subtitle>Recruiters, hiring managers and people who referred you.</:subtitle>
      <:actions>
        <.link patch={~p"/contacts/new"}>
          <.button>New contact</.button>
        </.link>
      </:actions>
    </.header>

    <form id="contact-search" phx-change="search" phx-submit="search" class="mt-6 max-w-sm">
      <input
        type="search"
        name="search"
        value={@search}
        placeholder="Search by name, title, email or company"
        phx-debounce="300"
        class="block w-full rounded-lg border-zinc-300 text-sm focus:border-zinc-400 focus:ring-0"
      />
    </form>

    <.empty_state :if={@contacts == []} class="mt-6">
      {if @search == "", do: "No contacts yet.", else: "No contacts match your search."}
    </.empty_state>

    <.table :if={@contacts != []} id="contacts" rows={@contacts} row_id={&"contacts-#{&1.id}"}>
      <:col :let={contact} label="Name">
        <p class="font-medium">{contact.name}</p>
        <p :if={contact.title} class="text-xs font-normal text-zinc-500">{contact.title}</p>
      </:col>
      <:col :let={contact} label="Company">
        <.link
          :if={contact.company}
          navigate={~p"/companies/#{contact.company}"}
          class="hover:underline"
        >
          {contact.company.name}
        </.link>
        <span :if={!contact.company}>—</span>
      </:col>
      <:col :let={contact} label="Email">
        <a :if={contact.email} href={"mailto:#{contact.email}"} class="text-brand hover:underline">{contact.email}</a>
      </:col>
      <:col :let={contact} label="Phone">{contact.phone}</:col>
      <:col :let={contact} label="Last contacted">{Format.date(contact.last_contacted_on)}</:col>
      <:action :let={contact}>
        <a
          :if={contact.linkedin_url}
          href={contact.linkedin_url}
          target="_blank"
          rel="noopener noreferrer"
        >LinkedIn</a>
      </:action>
      <:action :let={contact}>
        <.link patch={~p"/contacts/#{contact}/edit"}>Edit</.link>
      </:action>
      <:action :let={contact}>
        <.link
          phx-click={JS.push("delete", value: %{id: contact.id})}
          data-confirm="Delete this contact?"
        >
          Delete
        </.link>
      </:action>
    </.table>

    <.modal
      :if={@live_action in [:new, :edit]}
      id="contact-modal"
      show
      on_cancel={JS.patch(~p"/contacts")}
    >
      <.live_component
        module={JobTrackerWeb.ContactLive.FormComponent}
        id={@contact.id || :new}
        title={@page_title}
        action={@live_action}
        contact={@contact}
        current_user={@current_user}
        patch={~p"/contacts"}
      />
    </.modal>
    """
  end
end
