require 'rubygems'
require 'spork'

Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] ||= 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  require 'mongoid-rspec'

  # require machinist blueprints
  require File.expand_path(File.dirname(__FILE__) + "/blueprints")

  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

  Dir[Rails.root.join("lib/**/*.rb")].each {|f| require f}

  RSpec.configure do |config|
    config.include Mongoid::Matchers

    config.mock_with :rspec

    config.treat_symbols_as_metadata_keys_with_true_values = true
    config.filter_run :focus => true
    config.run_all_when_everything_filtered = true

    # Clean up all collections before each spec runs.
    config.before do
      Mongoid.purge!

      padma_account = PadmaAccount.new(:name => "mockedAccount")
      PadmaAccount.stub!(:find).and_return(padma_account)
    end
  end

end

Spork.each_run do
  # This code will be run each time you run your specs.
end if Spork.using_spork?