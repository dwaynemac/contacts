class PadmaUser < LogicalModel
  self.hydra = HYDRA
  self.use_ssl = (Rails.env=="production")

  self.resource_path = "/v0/users"
  self.attribute_keys = [:drc_login, :locale, :accounts ]
  self.use_api_key = true
  self.api_key_name = "token"
  self.api_key = "8c330b5d70f86ebfa6497c901b299b79afc6d68c60df6df0bda0180d3777eb4a5528924ac96cf58a25e599b4110da3c4b690fa29263714ec6604b6cb2d943656"
  self.host  = PADMA_ACCOUNTS_HOST

  TIMEOUT = 5500 # milisecons
  PER_PAGE = 9999

  # Returns me accounts as Padma::Account objects
  # @return [Array <PadmaAccount>]
  def padma_accounts
    self.accounts.map{|a|PadmaAccount.new(a)}
  end

  # Returns me enabled accounts as Padma::Account objects
  # @return [Array <PadmaAccount>] enabled accounts
  def enabled_accounts
    return [] if self.accounts.nil?
    self.accounts.reject{|a|!a['enabled']}.map{|a|PadmaAccount.new(a)}
  end
end
