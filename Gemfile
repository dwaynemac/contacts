source 'http://rubygems.org'

gem 'rails', '3.1.0'

# Bundle edge Rails instead:
# gem 'rails',     :git => 'git://github.com/rails/rails.git'

# gem 'sqlite3'

gem "mongoid", "2.3.3"
gem 'bson', '= 1.4.0'
gem "bson_ext", "= 1.4.0"
gem 'mongoid_search'

gem 'cancan', '~> 1.6.7'

gem "logical_model", :git =>'git@github.com:lperichon/logical_model.git'

gem 'kaminari', '0.12.4'

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
  gem 'thin'
  gem "machinist"
  gem 'machinist_mongo', :require => 'machinist/mongoid'
  gem 'faker', '0.9.4'
  gem "rspec-rails", "~> 2.4"
  gem "shoulda"
  gem 'mongoid-rspec'
  gem "database_cleaner", ">= 0.6.7", :group => :test
  gem "cucumber-rails"
  gem "timecop"

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
