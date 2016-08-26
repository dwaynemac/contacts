# encoding: UTF-8

class MailchimpSegment
  include Mongoid::Document

  field :statuses
  field :gender
  field :coefficients
  field :followed_by
  field :name
  field :mailchimp_id

  belongs_to :mailchimp_synchronizer
  before_save :set_default_attributes
  
  before_destroy :sync_before_segment_destruction 
  before_create :create_segment_in_mailchimp
  
  def to_query (negative = false)
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
      if !mailchimp_id.nil?
        api = Gibbon::API.new(synchro.api_key)
        api.lists.segment_del({
          id: synchro.list_id,
          seg_id: mailchimp_id     
        })
      end
    rescue Gibbon::MailChimpError => e
      raise unless e.message =~ /Invalid MailChimp List ID|This account has been deactivated/
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
    api = Gibbon::API.new(synchro.api_key)
    response = api.lists.segment_add({
      id: synchro.list_id,
      opts: {
        type: 'saved',
        name: name,
        segment_opts: {
          match: 'all',
          conditions: segment_conditions
        }
      }
    })
    self.mailchimp_id = response['id']
  rescue Gibbon::MailChimpError => e
    Rails.logger.warn "Couldnt create segment #{self.id} in Mailchimp. Error: #{e.message}"
    return nil
  end
  
  def segment_conditions
    conditions = []
    conditions << status_condition unless statuses.empty?   
    conditions << coefficient_condition unless coefficients.empty?
    conditions << gender_condition unless gender.blank?
    conditions << followed_by_condition unless followed_by.empty?
    conditions
  end

  # The order here is IMPORTANT 
  def status_condition
    value = '|'
    value << 'p' if statuses.include?('prospect')
    value << 's' if statuses.include?('student')
    value << 'f' if statuses.include?('former_student')
    value << '|'
    {
      field: 'SYSSTATUS',
      op: 'like',
      value: value
    }
  end
  
  def gender_condition
    {
      field: 'GENDER',
      op: 'eq',
      value: I18n.t("mailchimp.gender.#{gender}")
    }
  end
  
  def coefficient_condition
    #coefficient = 'fp'
    #if coefficients.include?('perfil')
    #  coefficient = 'perfil'
    #elsif coefficients.include?('pmas')
    #  coefficient = 'pmas'
    #end
    
    {
      field: "interests-#{mailchimp_synchronizer.coefficient_group}",
      op: 'one',
      value: coefficients.join(",")
    }
  end

  def followed_by_condition
    {
      field: 'FOLLOWEDBY',
      op: 'like',
      value: followed_by
    }
  end

  private 
  def set_default_attributes
    self.statuses = [] if self.statuses.nil?
    self.coefficients = [] if self.coefficients.nil?
  end 
  
end
