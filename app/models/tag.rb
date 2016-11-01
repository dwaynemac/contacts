class Tag
  include Mongoid::Document

  include AccountNameAccessor

  field :name
  belongs_to :account
  references_and_referenced_in_many :contacts

  validates :name, :presence => true
  validates :account, :presence => true

  validates_uniqueness_of :name, :scope => :account_id

  def self.remove_all_empty
    non_associated_tags = Tag.any_of({:contact_ids => nil}, {:contact_ids => []})
    non_associated_tags.delete_all
  end

  def as_json(options = nil)
    options = {} if options.nil?
    json = super options.merge({except: :account_id, methods: [:account_name]})
  end

  class << self
    # adds given tags to all given contacts
    # @param [Array] tag_ids
    # @param [Array] contact_ids
    def batch_add(tag_ids, contact_ids)
      tags = Tag.find(tag_ids)
      contacts = Contact.find(contact_ids)
      
      contacts.each do |contact|
        contact.tags += tags
        contact.save
        contact.index_keywords!
      end
    end
    #handle_asynchronously :batch_add, priority: -1
  end
end
