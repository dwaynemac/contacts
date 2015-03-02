class Enrollment < LogicalModel
  self.log_path = (Rails.env=="production")? STDOUT : "log/logical_model.log"

  self.hydra = HYDRA
  self.use_ssl = (Rails.env == "production")
  self.resource_path = "/api/v0/enrollments"
  self.attribute_keys = [
    :account_name,
    :username,
    :contact_id,
    :observations,
    :public,
    :level_cache,
    :communication_id,
    :changed_at,
    :created_at,
    :updated_at
  ]
  self.use_api_key = true
  self.api_key_name = "app_key"
  self.api_key = ENV['crm_key']
  self.host  = PADMA_CRM_HOST

  def json_root
    'enrollment'
  end
end
