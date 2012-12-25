source 'http://rubygems.org'

gem 'rails', '3.1.6'

gem 'unicorn'

gem "mongoid", "2.3.3"
gem 'bson', '= 1.4.0'
gem "bson_ext", "= 1.4.0"
gem 'mongoid_search'

gem 'cancan', '~> 1.6.7'


gem "logical_model", '~> 0.4.4'
gem 'activity_stream_client', '~> 0.0.10'
gem 'overmind_client', '~> 0.0.1'

gem 'kaminari', '~> 0.13'

gem 'rmagick'
gem 'carrierwave'
gem 'carrierwave-mongoid', :require => 'carrierwave/mongoid'
gem 'fog'
gem 'state_machine', '~> 1.1.2'
gem 'ethon', '0.4.2'

group :documentation do
  gem 'yard', '~> 0.7.4'
  gem 'yard-rest', :git => "git://github.com/dwaynemac/yard-rest-plugin.git"
end

group :production do
  gem 'newrelic_rpm'
end

group :development, :test do
  gem "timecop", '0.3.5'

  # Guard
  gem 'spork', "> 0.9.0.rc"
  gem 'guard-spork'
  gem 'guard-rspec'

  # guard notifications on MAC OS X
  gem 'rb-fsevent', :require => false if RUBY_PLATFORM =~ /darwin/i
  gem 'growl', :require => false if RUBY_PLATFORM =~ /darwin/i

  # guard notifications on Linux
  gem 'rb-inotify', :require => false if RUBY_PLATFORM =~ /linux/i
  gem 'libnotify', :require => false if RUBY_PLATFORM =~ /linux/i
end

group :test do
  gem "cucumber-rails", '1.2.0'
  gem "rspec-rails", "~> 2.4"
  gem "shoulda-matchers"
  gem 'mongoid-rspec', '1.4.4'
  gem "machinist", '1.0.6'
  gem 'machinist_mongo', '1.2.0', :require => 'machinist/mongoid'
  gem 'faker', '0.9.4'
  gem "database_cleaner", ">= 0.6.7"
end
