# wrapper for PADMA-Accounts Account API interaction
# Configuration for LogicalModel on /config/initializers/logical_model.rb
class PadmaAccount < LogicalModel
  self.hydra = HYDRA
  self.use_ssl = (Rails.env=="production")

  self.log_path = (Rails.env=="production")? STDOUT : "log/logical_model.log"

  self.resource_path = "/v0/accounts"
  self.attribute_keys = [:id, :name, :enabled ]
  self.use_api_key = true
  self.api_key_name = "token"
  self.api_key = "8c330b5d70f86ebfa6497c901b299b79afc6d68c60df6df0bda0180d3777eb4a5528924ac96cf58a25e599b4110da3c4b690fa29263714ec6604b6cb2d943656"
  self.host  = PADMA_ACCOUNTS_HOST

  TIMEOUT = 5500 # ms
  PER_PAGE = 9999

  def enabled?
    self.enabled
  end

  def users
    PadmaUser.paginate :params => { :account_name => self.name }
  end
end