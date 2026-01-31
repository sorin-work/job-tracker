defmodule JobTrackerWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use JobTrackerWeb, :controller` and
  `use JobTrackerWeb, :live_view`.
  """
  use JobTrackerWeb, :html

  embed_templates "layouts/*"

  def nav_items do
    [
      {"Dashboard", ~p"/dashboard", :dashboard},
      {"Board", ~p"/board", :board},
      {"Applications", ~p"/applications", :applications},
      {"Interviews", ~p"/interviews", :interviews},
      {"Reminders", ~p"/reminders", :reminders},
      {"Companies", ~p"/companies", :companies},
      {"Contacts", ~p"/contacts", :contacts}
    ]
  end
end
