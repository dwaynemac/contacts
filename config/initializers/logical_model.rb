HYDRA = Typhoeus::Hydra.new

PADMA_FNZ_HOST = case Rails.env
  when "production"
    "fnz.herokuapp.com"
  when "staging"
    "fnz-staging.herokuapp.com"
  when "development"
    "localhost:3010"
  when "test"
    "localhost:3010"
end

PADMA_PLANNING_HOST = case Rails.env
  when "production"
    "padma-planning.herokuapp.com"
  when "staging"
    "padma-planning-staging.herokuapp.com"
  when "development"
    "localhost:3005"
  when "test"
    "localhost:3005"
end

PADMA_ACCOUNTS_HOST = case Rails.env
  when "production"
    "accounts.padm.am"
  when "staging"
    "padma-accounts-staging.herokuapp.com"
  when "development"
    "localhost:3001"
  when "test"
    "localhost:3001"
end

PADMA_CRM_HOST = case Rails.env
  when "production"
    "crm.padm.am"
  when "staging"
    "padma-crm-staging.herokuapp.com"
  when "development"
    "localhost:3000"
  when "test"
    "localhost:3000"
end

module Accounts
  API_KEY = ENV['accounts_key']
  HYDRA = ::HYDRA
end

module ActivityStream
  HYDRA = ::HYDRA
  API_KEY = ENV['activity_key']
end

module Messaging
  HYDRA = ::HYDRA
  API_KEY = ENV['messaging_key']
end

class LogicalModel
  if Rails.env.production? || Rails.env.staging?
    def self.logger
      Logger.new(STDOUT)
    end
  end
end

module Overmind
  HYDRA = ::HYDRA
  API_KEY = ENV['overmind_key']
end
