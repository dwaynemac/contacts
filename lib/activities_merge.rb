# wrapper for CRM-Merge API interaction
# Configuration for LogicalModel on /config/initializers/logical_model.rb
class ActivitiesMerge < LogicalModel

  self.log_path = (Rails.env=="production")? STDOUT : "log/logical_model.log"

  self.hydra = HYDRA
  self.use_ssl = (Rails.env == "production")
  self.resource_path = "/v0/merges"
  self.attribute_keys = [:parent_id, :son_id]
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = "6d1a2dd931ef48d5f0c4d62de773825d3369ab426811c79c55e40569bc7bf044a437bbf569f765e6fd3a282ab43a27a2cb48ee2bd08c8bf743190165cd2ecb76"
  self.host  = PADMA_ACTIVITY_STREAM_HOST

  def json_root
    'merge'
  end

end
