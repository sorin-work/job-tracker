defmodule JobTrackerWeb.Nav do
  @moduledoc """
  Sets the active navigation item and the number of due reminders shown in the
  navigation bar for every authenticated LiveView.
  """

  import Phoenix.Component

  alias JobTracker.Reminders

  @sections %{
    JobTrackerWeb.DashboardLive => :dashboard,
    JobTrackerWeb.BoardLive => :board,
    JobTrackerWeb.ApplicationLive.Index => :applications,
    JobTrackerWeb.ApplicationLive.Show => :applications,
    JobTrackerWeb.InterviewLive.Index => :interviews,
    JobTrackerWeb.ReminderLive.Index => :reminders,
    JobTrackerWeb.CompanyLive.Index => :companies,
    JobTrackerWeb.CompanyLive.Show => :companies,
    JobTrackerWeb.ContactLive.Index => :contacts,
    JobTrackerWeb.StatsLive => :stats,
    JobTrackerWeb.TagLive.Index => :applications
  }

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> assign(:active_nav, Map.get(@sections, socket.view))
      |> assign_due_count()

    {:cont, socket}
  end

  @doc """
  Recounts the due reminders, for views that complete or snooze them.
  """
  def assign_due_count(socket) do
    case socket.assigns[:current_user] do
      nil -> assign(socket, :due_count, 0)
      user -> assign(socket, :due_count, Reminders.count_due(user))
    end
  end
end
