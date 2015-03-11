class FnzMerge < LogicalModel
  self.log_path = (Rails.env=="production")? STDOUT : "log/logical_model.log"

  self.hydra = HYDRA
  self.use_ssl = (Rails.env == "production")
  self.resource_path = "/api/v0/merges"
  self.attribute_keys = [:father_id, :son_id]
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = ENV['fnz_key']
  self.host  = PADMA_FNZ_HOST

  def json_root
    'merge'
  end
end
