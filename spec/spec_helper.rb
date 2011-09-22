# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'mongoid-rspec'
require 'shoulda'

# require machinist blueprints
require File.expand_path(File.dirname(__FILE__) + "/blueprints")

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

Dir[Rails.root.join("lib/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  include Mongoid::Matchers

  # == Mock Framework
  #
  # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
  #
  # config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
  config.mock_with :rspec

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  #config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  #config.use_transactional_fixtures = true

  # Clean up all collections before each spec runs.
  config.before do
    Mongoid.purge!

    padma_account = PadmaAccount.new(:name => "mockedAccount")
    PadmaAccount.stub!(:find).and_return(padma_account)
  end
end