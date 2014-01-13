HYDRA = Typhoeus::Hydra.new

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
  API_KEY = "8c330b5d70f86ebfa6497c901b299b79afc6d68c60df6df0bda0180d3777eb4a5528924ac96cf58a25e599b4110da3c4b690fa29263714ec6604b6cb2d943656"
  HYDRA = ::HYDRA
end

module ActivityStream
  HYDRA = ::HYDRA
  API_KEY = "6d1a2dd931ef48d5f0c4d62de773825d3369ab426811c79c55e40569bc7bf044a437bbf569f765e6fd3a282ab43a27a2cb48ee2bd08c8bf743190165cd2ecb76"
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
  API_KEY = "secret-key"
end
