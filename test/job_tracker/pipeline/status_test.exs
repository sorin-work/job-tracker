defmodule JobTracker.Pipeline.StatusTest do
  use ExUnit.Case, async: true

  alias JobTracker.Pipeline.Status

  test "all statuses are in pipeline order" do
    assert Status.all() == [
             :wishlist,
             :applied,
             :screening,
             :interviewing,
             :offer,
             :accepted,
             :rejected,
             :withdrawn
           ]
  end

  test "rank/1 follows the progression and is nil for rejected and withdrawn" do
    assert Status.rank(:wishlist) == 0
    assert Status.rank(:offer) == 4
    assert Status.rank(:accepted) == 5
    assert Status.rank(:rejected) == nil
    assert Status.rank(:withdrawn) == nil
  end

  test "label/1 works with atoms and strings" do
    assert Status.label(:interviewing) == "Interviewing"
    assert Status.label("wishlist") == "Wishlist"
  end
end
