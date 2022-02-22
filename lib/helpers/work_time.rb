##
# Defines whether time to work has started
#
module WorkTime
  extend self

  HOUR = 60 * 60
  DELTA = 10 # if some calculation went wrong on writing working time
  HAUNT_MAX_WAIT = 1000

  ##
  # Define time to sleep for worker + DELTA (ocasionally time)
  #
  def wait_time(user_id)
    return 0 if FileBase.last_work(user_id).nil?

    time_to_wait = (FileBase.last_work(user_id).to_i + HOUR) - Time.now.to_i
    time_to_wait.negative? ? 0 : time_to_wait + DELTA
  end

  def hunt_wait_time
    rand(HAUNT_MAX_WAIT)
  end
end
