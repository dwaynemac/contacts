worker_processes 4
timeout 30
preload_app true

before_fork do |server, worker|

  # disconnect MongoDB
  # according to http://mongoid.org/en/mongoid/docs/rails.html and http://mongoid.ru/docs/integration/
  # mongoid doesn't need to manually do this

=begin
  # Replace with MongoDB or whatever
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
    Rails.logger.info('Disconnected from ActiveRecord')
  end
  sleep 1
=end

end

after_fork do |server, worker|

  # reconnect MongoDB
  # according to http://mongoid.org/en/mongoid/docs/rails.html and http://mongoid.ru/docs/integration/
  # mongoid doesn't need to manually do this

=begin
  # Replace with MongoDB or whatever
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.establish_connection
    Rails.logger.info('Connected to ActiveRecord')
  end
=end

end
