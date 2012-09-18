HYDRA = Typhoeus::Hydra.new

PADMA_ACCOUNTS_HOST = case Rails.env
  when "production"
    "padma-accounts.heroku.com"
  when "development"
    "localhost:3001"
  when "test"
    "localhost:3001"
end

PADMA_CRM_HOST = case Rails.env
  when "production"
    "padma-crm.heroku.com"
  when "development"
    "localhost:3000"
  when "test"
    "localhost:3000"
end
