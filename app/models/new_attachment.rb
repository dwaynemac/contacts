# @restful_api v0
#
# @property [String] name
#
# @example
#  blah
class NewAttachment < ActiveRecord::Base
  include ReadOnly
  include AccountNameAccessor
  
  self.table_name = "attachments"

  belongs_to :contact, class_name: 'NewContact'
  belongs_to :account, class_name: "NewAccount"
  has_one :import, class_name: "NewImport"

  has_objectid_columns :contact_id

  mount_uploader :file, AttachmentUploader

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

  # Returns Attachments visible to account
  #
  #
  # @param [Account] account
  # @param [Hash] options
  #
  #    @return [Criteria]
  def self.for_account(account, options = {})
    any_of({account_id: account.id}, { public: true})
  end
end
