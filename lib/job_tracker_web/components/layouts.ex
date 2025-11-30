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
      {"Applications", ~p"/applications", :applications},
      {"Companies", ~p"/companies", :companies}
    ]
  end
end
