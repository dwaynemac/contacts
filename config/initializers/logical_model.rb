HYDRA = Typhoeus::Hydra.new

PADMA_ACCOUNTS_HOST = case Rails.env
  when "production"
    "padma-accounts.heroku.com"
  when "development"
    "localhost:3001"
  when "test"
    "localhost:3001"
end