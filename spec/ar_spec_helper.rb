require 'rubygems'

require 'coveralls'
Coveralls.wear!

require 'database_cleaner'

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'shoulda-matchers'

# require machinist blueprints
require Rails.root.join('spec/ar_blueprints')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

Dir[Rails.root.join("lib/**/*.rb")].each {|f| require f}
Dir[Rails.root.join("app/**/concerns/*.rb")].each {|f| require f}

RSpec.configure do |config|
=begin
  # RSpec automatically cleans stuff out of backtraces;
  # sometimes this is annoying when trying to debug something e.g. a gem
  puts "                      ATTENTION: Backtraces are scoped to app code only."
  puts "                                 Edit spec_helper to debug all code"
  config.backtrace_exclusion_patterns = [
      /\/lib\d*\/ruby\//,
      /bin\//,
      /gems/,
      /spec\/spec_helper\.rb/,
      /lib\/rspec\/(core|expectations|matchers|mocks)/
  ]
=end
  config.include(Shoulda::Matchers::ActiveModel, type: :model)
  config.include(Shoulda::Matchers::ActiveRecord, type: :model)

  config.mock_with :rspec

  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true

  config.infer_spec_type_from_file_location!

  # Clean up all collections before each spec runs.
  config.before do
    # as classes are not being cached we need to reload blueprints
    load Rails.root.join('spec/ar_blueprints.rb')


    DatabaseCleaner.strategy = :transaction
    # then, whenever you need to clean the DB
    DatabaseCleaner.clean

    padma_account = PadmaAccount.new(:name => "mockedAccount")
    PadmaAccount.stub(:find).and_return(padma_account)
  end
end
