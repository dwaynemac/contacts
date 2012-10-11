# wrapper for CRM-Merge API interaction
# Configuration for LogicalModel on /config/initializers/logical_model.rb
class CrmMerge < LogicalModel

  self.hydra = HYDRA
  self.use_ssl = (Rails.env == "production")
  self.resource_path = "api/v0/merges"
  self.attribute_keys = [:parent_id, :son_id]
  self.use_api_key = false
  self.api_key_name = "token"
  self.api_key = "8c330b5d70f86ebfa6497c901b299b79afc6d68c60df6df0bda0180d3777eb4a5528924ac96cf58a25e599b4110da3c4b690fa29263714ec6604b6cb2d943656"
  self.host  = PADMA_CRM_HOST

  def json_root
    'merge'
  end
end
