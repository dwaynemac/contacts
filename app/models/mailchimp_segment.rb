# encoding: UTF-8

class MailchimpSegment
  include Mongoid::Document

  field :statuses
  field :gender
  field :coefficients
  field :followed_by
  field :name
  field :remote_id

  belongs_to :mailchimp_synchronizer
  before_save :set_default_attributes
  
  before_destroy :sync_before_segment_destruction 
  before_create :create_segment_in_mailchimp
  
  def to_query(negative = false)
    query = {}
    
    in_or_not_in = "$in"
    in_or_not_in = "$nin" if negative

    and_or_or = "$and"
    and_or_or = "$or" if negative
    
    criteria = []

    if !statuses.empty?
      criteria << {"local_unique_attributes" => 
        {"$elemMatch" => {
          "_type" => "LocalStatus",
          "account_id" => mailchimp_synchronizer.account.id,
          "value" => {in_or_not_in => statuses}
        }}
      }
    end

    if !coefficients.empty?
      if coefficients.include? "np"
        coefficients.delete("np")
        coefficients << "fp"
      end
      criteria << {"local_unique_attributes" =>
        {"$elemMatch" => {
          "_type" => "Coefficient",
          "account_id" => mailchimp_synchronizer.account.id,
          "value" => {in_or_not_in => coefficients}
        }}
      }
    end
    
    if !gender.blank?
      criteria << {"gender" => gender}
    end

    if !criteria.empty?
      query[and_or_or] = criteria
    end
    
    query  
  end

  def self.to_query(statuses, coefficients, gender, account_id, negative = false)
    query = {}
    
    in_or_not_in = "$in"
    in_or_not_in = "$nin" if negative

    and_or_or = "$and"
    and_or_or = "$or" if negative
    
    criteria = []

    if !statuses.blank?
      criteria << {"local_unique_attributes" => 
        {"$elemMatch" => {
          "_type" => "LocalStatus",
          "account_id" => account_id,
          "value" => {in_or_not_in => statuses}
        }}
      }
    end

    if !coefficients.blank?
      if coefficients.include? "np"
        coefficients << "fp"
      end
      criteria << {"local_unique_attributes" =>
        {"$elemMatch" => {
          "_type" => "Coefficient",
          "account_id" => account_id,
          "value" => {in_or_not_in => coefficients}
        }}
      }
    end
    
    if !gender.blank?
      criteria << {"gender" => gender}
    end

    if !criteria.empty?
      query[and_or_or] = criteria
    end
    
    query
  end
  
  def sync_before_segment_destruction
    synchro = mailchimp_synchronizer
    
    begin
      if !remote_id.nil?
        api = Gibbon::Request.new(api_key: synchro.api_key)
        api.lists(synchro.list_id).segments(remote_id).delete
      end
    rescue Gibbon::MailChimpError => e
      raise unless e.message =~ /Invalid MailChimp List ID|This account has been deactivated|Resource Not Found/
    end

    if synchro.filter_method == 'segments'
      other_segments = synchro.mailchimp_segments.reject {|s| s.id == self.id}
      querys = other_segments.map {|s| s.to_query(true)}
      querys << self.to_query
      synchro.unsubscribe_contacts(querys)
    end
  end
  
  def create_segment_in_mailchimp
    synchro = mailchimp_synchronizer
    synchro.set_i18n
    begin
      api = Gibbon::Request.new(api_key: synchro.api_key)
      response = api.lists(synchro.list_id).segments.create(
        body: {
          name: name,
          options: {
            match: 'all',
            conditions: segment_conditions
          }
        }
      )
      self.remote_id = response.body['id']
    rescue Gibbon::MailChimpError => e
      synchro.update_attribute(:status, :failed)
      synchro.email_admins_about_failure(synchro.account.name, e.message)
      Rails.logger.warn "Couldnt create segment #{self.id} in Mailchimp. Error: #{e.message}"
    end
    return nil
  end
  
  def segment_conditions
    conditions = []
    conditions << { 
      condition_type: "TextMerge",
      field: 'SYSSTATUS',
      op: 'contains', 
      value: status_condition} unless statuses.empty?
    conditions << {
      condition_type: "Interests",
      field: "interests-#{ActiveSupport::JSON.decode(mailchimp_synchronizer.coefficient_group)["id"]}",
      op: 'interestcontains',
      value: coefficient_condition} unless coefficients.empty?
    conditions << {
      condition_type: "TextMerge",
      field: "GENDER",
      op: "is",
      value: gender_condition} unless gender.blank?
    conditions << {
      condition_type: "TextMerge",
      field: "FOLLOWEDBY",
      op: "contains",
      value: followed_by_condition} unless followed_by.empty?
    conditions
  end

  # The order here is IMPORTANT 
  def status_condition
    value = '|'
    value << 'p' if statuses.include?('prospect')
    value << 's' if statuses.include?('student')
    value << 'f' if statuses.include?('former_student')
    value << '|'
    value
  end
  
  def gender_condition
    I18n.t("mailchimp.gender.#{gender}")
  end
  
  def coefficient_condition
    mailchimp_synchronizer.get_interests_ids(coefficients.join(","))
  end

  def followed_by_condition
    followed_by
  end

  private 
  def set_default_attributes
    self.statuses = [] if self.statuses.nil?
    self.coefficients = [] if self.coefficients.nil?
  end 
  
end
