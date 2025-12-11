defmodule JobTrackerWeb.Nav do
  @moduledoc """
  Sets the active navigation item for every authenticated LiveView.
  """

  import Phoenix.Component

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

    {:cont, socket}
  end
end
