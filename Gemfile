source 'http://rubygems.org'
ruby '1.9.3'

gem 'rails', '~> 3.1.0'

gem 'unicorn'
gem 'unicorn-worker-killer'
gem "mongoid", "2.3.3"
gem 'bson', '= 1.4.0'
gem "bson_ext", "= 1.4.0"
gem 'mongoid_search'

gem 'cancan', '~> 1.6.7'

gem "logical_model", '~> 0.6.4'
gem 'activity_stream_client', '~> 0.0.14'
gem 'overmind_client', '~> 0.0.6'
gem 'accounts_client', '>= 0.2.15'
gem 'messaging_client', '0.0.4'

gem 'gibbon'

gem 'kaminari', '~> 0.13'

gem 'aws-ses'

gem 'oj'

gem 'rmagick'
gem 'carrierwave'
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
gem 'fog'
gem 'unf'
gem 'state_machine', '~> 1.1.2'
gem 'ethon', '0.4.2'

gem 'delayed_job_mongoid' # Gem for managing background operations
gem 'workless'
gem 'daemons'

gem 'figaro' # for environment variables managment

gem 'rake'

gem 'i18n', '~> 0.6.6'

gem 'minitest'

gem 'rack-cors', :require => 'rack/cors'

group :documentation do
  gem 'yard', '~> 0.8.3'
  gem 'yard-restful'
  gem 'redcarpet'
end

group :production do
  gem 'dalli' # memcache support on heroku
  gem 'memcachier' # memcache migrator for heroku
end

group :heroku do
  gem 'heroku-mongo-backup', '~> 0.4.3' # Gem for making mongo -> AmazonS3 backups
end

gem 'appsignal', '0.11.17', group: [:production, :development, :deploying]
gem 'appsignal-mongo', group: [:production, :development]

group :development do
  gem 'git-pivotal-tracker-integration'

  gem 'debugger'
  gem 'ruby-mass'
end

group :deployment do
  gem 'capistrano', '~> 3.1'
  gem 'capistrano-ext'
  gem 'capistrano-rails', '~> 1.1'
  gem 'capistrano-bundler'
  gem 'capistrano3-unicorn'
end

group :development, :test do
  gem "timecop", '0.3.5'

  # Guard
  gem 'guard-rspec'

  # guard notifications on MAC OS X
  gem 'rb-fsevent', :require => false if RUBY_PLATFORM =~ /darwin/i
  gem 'growl', :require => false if RUBY_PLATFORM =~ /darwin/i

  # guard notifications on Linux
  gem 'rb-inotify', :require => false if RUBY_PLATFORM =~ /linux/i
  gem 'libnotify', :require => false if RUBY_PLATFORM =~ /linux/i
end

# needed for rake ¿?
gem "rspec-rails", "~> 2.14"
  
group :test do
  gem "shoulda-matchers", :require => false
  gem "machinist", '1.0.6'
  gem 'machinist_mongo', '1.2.0', :require => 'machinist/mongoid'
  gem 'mongoid-rspec', '1.4.4'
  gem 'faker', '0.9.4'
  gem "database_cleaner", ">= 0.6.7"
  gem 'coveralls', require: false
end
