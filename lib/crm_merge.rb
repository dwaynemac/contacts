# wrapper for CRM-Merge API interaction
# Configuration for LogicalModel on /config/initializers/logical_model.rb
class CrmMerge < LogicalModel

  self.log_path = (Rails.env=="production")? STDOUT : "log/logical_model.log"

  self.hydra = HYDRA
  self.use_ssl = (Rails.env == "production")
  self.resource_path = "/api/v0/merges"
  self.attribute_keys = [:parent_id, :son_id]
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = ENV['crm_key']
  self.host  = PADMA_CRM_HOST

  def json_root
    'merge'
  end
end
