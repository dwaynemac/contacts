HYDRA = Typhoeus::Hydra.new

PADMA_ACCOUNTS_HOST = case Rails.env
  when "production"
    "padma-accounts.heroku.com"
  when "staging"
    "padma-accounts-staging.herokuapp.com"
  when "development"
    "localhost:3001"
  when "test"
    "localhost:3001"
end

PADMA_CRM_HOST = case Rails.env
  when "production"
    "padma-crm.herokuapp.com"
  when "staging"
    "padma-crm-staging.herokuapp.com"
  when "development"
    "localhost:3000"
  when "test"
    "localhost:3000"
end

module ActivityStream
  HYDRA = ::HYDRA
  API_KEY = "6d1a2dd931ef48d5f0c4d62de773825d3369ab426811c79c55e40569bc7bf044a437bbf569f765e6fd3a282ab43a27a2cb48ee2bd08c8bf743190165cd2ecb76"
end

class LogicalModel
  if Rails.env.production? || Rails.env.staging?
    def self.logger
      Logger.new(STDOUT)
    end
  end
end
