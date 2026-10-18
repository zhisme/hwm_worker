##
# Picks when the next hunt should happen and leaves it where the cluster can
# find it.
#
# Hunting at a fixed hour every day is an obvious bot signature, so after each
# hunt we draw a random gap and write the resulting time as a cron expression to
# the shared volume. The hunter-scheduler CronJob in zhisme-infra reads that file
# and patches the hunter CronJob's schedule with it.
#
module HuntSchedule
  extend self

  DEFAULT_MIN_GAP = 4 * 60 * 60
  DEFAULT_MAX_GAP = 20 * 60 * 60
  DEFAULT_PATH = 'file_base/next_hunt_schedule'.freeze

  ##
  # Draws the next run time, writes it, and returns it.
  # Returns nil if the file could not be written — the hunt itself already
  # succeeded, so a bad volume must not fail the job.
  #
  # @param now [Time]
  # @return [Time, nil]
  #
  def write_next_run(now = Time.now)
    at = next_run_at(now)
    File.write(path, cron_expression(at))
    WorkLogger.current.info { "Next hunt scheduled at #{at} (#{cron_expression(at)})" }
    at
  rescue SystemCallError, IOError => e
    WorkLogger.current.error { "Cannot write next hunt schedule to #{path}, keeping current one: #{e.message}" }
    nil
  end

  ##
  # @param now [Time]
  # @return [Time]
  #
  def next_run_at(now = Time.now)
    raise ArgumentError, "max gap #{max_gap} is smaller than min gap #{min_gap}" if max_gap < min_gap

    now + min_gap + rand(max_gap - min_gap + 1)
  end

  ##
  # Minute and hour only, so the job fires once at that time each day until the
  # next hunt moves it again.
  #
  # @param time [Time]
  # @return [String]
  #
  def cron_expression(time)
    "#{time.min} #{time.hour} * * *"
  end

  private

  def min_gap
    Integer(ENV.fetch('HUNT_MIN_GAP_SECONDS', DEFAULT_MIN_GAP))
  end

  def max_gap
    Integer(ENV.fetch('HUNT_MAX_GAP_SECONDS', DEFAULT_MAX_GAP))
  end

  def path
    ENV.fetch('HUNT_SCHEDULE_FILE', DEFAULT_PATH)
  end
end
