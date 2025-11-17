require 'logger'

##
# Used to log actions by application
# Logs to STDOUT for Docker/Kubernetes compatibility
#
class WorkLogger
  @current = Logger.new(STDOUT)

  class << self
    attr_reader :current
  end
end
