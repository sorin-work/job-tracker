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

  test "open and closed split the statuses" do
    assert Status.open() ++ Status.closed() == Status.all()
    assert Status.closed?(:rejected)
    refute Status.closed?(:offer)
  end

  test "rank/1 follows the progression and is nil for rejected and withdrawn" do
    assert Status.rank(:wishlist) == 0
    assert Status.rank(:offer) == 4
    assert Status.rank(:accepted) == 5
    assert Status.rank(:rejected) == nil
    assert Status.rank(:withdrawn) == nil
  end

  test "cast/1 accepts known strings and atoms only" do
    assert Status.cast("screening") == {:ok, :screening}
    assert Status.cast(:offer) == {:ok, :offer}
    assert Status.cast("hired") == :error
    assert Status.cast(nil) == :error
    assert_raise ArgumentError, fn -> Status.cast!("hired") end
  end

  test "label/1 works with atoms and strings" do
    assert Status.label(:interviewing) == "Interviewing"
    assert Status.label("wishlist") == "Wishlist"
  end
end
