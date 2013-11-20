# @restful_api v0
#
# @property [String] name
#
# @example
#  blah
class Attachment
  include Mongoid::Document
  include ReadOnly
  include AccountNameAccessor
  
  embedded_in :contact
  embedded_in :import

  field :public, type: Boolean
  field :name, type: String
  field :description, type: String

  field :file
  mount_uploader :file, AttachmentUploader

  referenced_in :account
  validates :name, :presence => true

  before_save :assign_owner

  # - replaces :account_id with :account_name
  # - adds :_type, :contact_id
  #
  # @param options [Hash]
  def as_json(options={})
    options = {} if options.nil?
    options[:methods] = [:_type, :contact_id, :account_name] + ( options[:methods].try(:to_a) || [])
    options[:except]  = [:account_id] + ( options[:except].try(:to_a) || [])

    super(options)
  end

  def assign_owner
    return unless self.account.blank?

    if self.contact.present?
      self.account_id = self.contact.owner_id
    elsif self.import.present?
      self.account_id = self.import.account_id
    end
  end

  def contact_id
    contact.id
  end
end
