# This file is used by Rack-based servers to start the application.
# Unicorn self-process killer
require 'unicorn/worker_killer'
# Max memory size (RSS) per worker
# Kill range: 500-900 Mb
use Unicorn::WorkerKiller::Oom, (400*(1024**2)), (600*(1024**2))

require ::File.expand_path('../config/environment',  __FILE__)
run Contacts::Application
