# wrapper for CRM-Merge API interaction
# Configuration for LogicalModel on /config/initializers/logical_model.rb
class CrmMerge < LogicalModel

  self.hydra = HYDRA
  self.use_ssl = (Rails.env == "production")
  self.resource_path = "/api/v0/merges"
  self.attribute_keys = [:parent_id, :son_id]
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = "844d8c2d20"
  self.host  = PADMA_CRM_HOST

  def json_root
    'merge'
  end
end
