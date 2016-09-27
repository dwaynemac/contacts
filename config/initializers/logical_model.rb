HYDRA = Typhoeus::Hydra.new

PADMA_ATTENDANCE_HOST = case Rails.env
  when "production"
    "padma-attendance.herokuapp.com"
  when "staging"
    "padma-attendance-staging.herokuapp.com"
  when "development"
    (ENV['C9_USER'])? "padma-attendance-#{ENV['C9_USER']}.c9users.io" : "localhost:3004"
  when "test"
    "localhost:3004"
end

PADMA_MAILING_HOST = case Rails.env
  when "production"
    "padma-mailing.herokuapp.com"
  when "staging"
    "padma-mailing-staging.herokuapp.com"
  when "development"
    "localhost:3020"
  when "test"
    "localhost:3020"
end

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
    (ENV['C9_USER'])? "padma-accounts-#{ENV['C9_USER']}.c9users.io" : "localhost:3001"
  when "test"
    "localhost:3001"
end

PADMA_CRM_HOST = case Rails.env
  when "production"
    "crm.padm.am"
  when "staging"
    "padma-crm-staging.herokuapp.com"
  when "development"
    (ENV['C9_USER'])? "padma-crm-#{ENV['C9_USER']}.c9users.io" : "localhost:3000"
  when "test"
    "localhost:3000"
end

module Accounts
  API_KEY = ENV['accounts_key']
  HYDRA = ::HYDRA
  if ENV['C9_USER']
    HOST = PADMA_ACCOUNTS_HOST
  end
end

module ActivityStream
  HYDRA = ::HYDRA
  API_KEY = ENV['activity_key']
  if ENV['C9_USER']
    HOST = "padma-activity-stream-#{ENV['C9_USER']}.c9users.io"
  end
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
