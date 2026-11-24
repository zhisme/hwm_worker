##
# Used to write file actions needed by app. Simple file db
#
module FileBase
  extend self

  PATH = Pathname.new('file_base')

  def last_work(user_id)
    return unless File.exist?(last_work_user_path(user_id))

    File.read(last_work_user_path(user_id)).strip
  end

  def write_last_work(user_id)
    File.open(last_work_user_path(user_id), 'w+') do |f|
      f.puts Time.now.to_i
    end
  end

  ##
  # Counts hunts for today and returns the new count, so a streak of
  # non-qualifying wins cannot drain the mirror.
  #
  def register_hunt(user_id)
    today = Time.now.strftime('%F')
    date, count = last_hunt(user_id)
    count = date == today ? count : 0
    count += 1
    File.write(hunt_counter_user_path(user_id), "#{today} #{count}")
    count
  end

  private

  def last_hunt(user_id)
    path = hunt_counter_user_path(user_id)
    return [nil, 0] unless File.exist?(path)

    date, count = File.read(path).split
    [date, count.to_i]
  end

  def hunt_counter_user_path(user_id)
    PATH.join "hunts-#{user_id}.db"
  end

  def last_work_user_path(user_id)
    PATH.join "last-work-#{user_id}.db"
  end
end
