source 'http://rubygems.org'

gem 'rails', '3.1.0'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# gem 'sqlite3'

gem "mongoid", "~> 2.2"
gem "bson_ext", "~> 1.3"

gem 'typhoeus', '0.2.4'
gem "logical_model", "~> 0.1.6"

# Gems used only for assets and not required
# in production environments by default.
#group :assets do
#  gem 'sass-rails', "  ~> 3.1.0"
#  gem 'coffee-rails', "~> 3.1.0"
#  gem 'uglifier'
#end



# Use unicorn as the web server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

# To use debugger
# gem 'ruby-debug19', :require => 'ruby-debug'

group :development, :test do
  gem "machinist"
  gem 'machinist_mongo', :require => 'machinist/mongoid'
  gem 'faker', '0.9.4'
  gem "shoulda"
  gem "rspec-rails", "~> 2.4"
  gem 'mongoid-rspec'
  gem "database_cleaner", ">= 0.6.7", :group => :test
  gem "cucumber-rails"
  gem "timecop"

  # Guard
  gem 'guard-rspec'

  # guard notifications on MAC OS X
  gem 'rb-fsevent', :require => false if RUBY_PLATFORM =~ /darwin/i
  gem 'growl', :require => false if RUBY_PLATFORM =~ /darwin/i

  # guard notifications on Linux
  gem 'rb-inotify', :require => false if RUBY_PLATFORM =~ /linux/i
  gem 'libnotify', :require => false if RUBY_PLATFORM =~ /linux/i
end