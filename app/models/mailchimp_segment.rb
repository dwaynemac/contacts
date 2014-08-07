# encoding: UTF-8

class MailchimpSegment
  include Mongoid::Document

  field :statuses
  field :gender
  field :coefficients

  belongs_to :mailchimp_synchronizer
  before_save :set_default_attributes
  
  def to_query
    query = {}
    
    #local_unique_attributes_criteria
    luac = []
    if !statuses.empty?
      luac << {"local_unique_attributes" => 
        {"$elemMatch" => {
          "_type" => "LocalStatus",
          "account_id" => mailchimp_synchronizer.account.id,
          "value" => {"$in" => statuses}
        }}
      }
    end

    if !coefficients.empty?
      luac << {"local_unique_attributes" =>
        {"$elemMatch" => {
          "_type" => "Coefficient",
          "account_id" => mailchimp_synchronizer.account.id,
          "value" => {"$in" => coefficients}
        }}
      }
    end
    
    if !luac.empty?
      query["$and"] = luac
    end
    
    if !gender.nil?
      query['gender'] = gender
    end
    
    query  
  end
  
  private 
  def set_default_attributes
    self.statuses = [] if self.statuses.nil?
    self.coefficients = [] if self.coefficients.nil?
  end 
  
end
