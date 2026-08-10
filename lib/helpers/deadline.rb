##
# Tracks how much wall clock the process is still allowed to burn.
#
# Kubernetes counts activeDeadlineSeconds from Job creation, not from the
# moment ruby boots, so DEADLINE_SECONDS is expected to be activeDeadlineSeconds
# already discounted by pod scheduling and selenium warmup.
#
# Unset (or 0) means no budget tracking, which is what local runs want.
#
module Deadline
  extend self

  BUDGET = Integer(ENV.fetch('DEADLINE_SECONDS', 0))

  # Left free at the end so a doomed step reports itself instead of being
  # SIGTERMed halfway through a form submit.
  RESERVE = 20

  ##
  # Freeze the start of the budget. Called once during boot.
  #
  def start!
    @started_at = monotonic
    self
  end

  def unlimited?
    BUDGET.zero?
  end

  ##
  # Seconds still available before RESERVE kicks in. Can go negative.
  #
  def left
    return Float::INFINITY if unlimited?

    start! if @started_at.nil?

    BUDGET - RESERVE - (monotonic - @started_at)
  end

  def exceeded?
    left <= 0
  end

  ##
  # Seconds burned since boot, for phase timing in logs.
  #
  def elapsed
    start! if @started_at.nil?

    (monotonic - @started_at).round
  end

  ##
  # Remaining budget rendered for logs, since left is Infinity when unlimited.
  #
  def left_for_log
    remaining = left

    remaining.infinite? ? 'unlimited' : "#{remaining.round}s"
  end

  ##
  # Test seam, also lets bin/hunt and bin/run share the module safely.
  #
  def reset!
    @started_at = nil
  end

  private

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
