
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "hwm_worker/version"

Gem::Specification.new do |spec|
  spec.name          = "hwm_worker"
  spec.version       = HwmWorker::VERSION
  spec.authors       = ["Zhdanov"]
  spec.email         = ["evdev34@gmail.com"]

  spec.summary       = "Hwm worker for http://heroeswm.ru/"
  spec.homepage      = "https://github.com/zhisme/hwm_worker"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "selenium-webdriver", '~> 4.29', '>= 4.29.1'
  spec.add_dependency "capybara", '~> 3.40'
  spec.add_dependency "rest-client"
  spec.add_dependency "rollbar"

end
