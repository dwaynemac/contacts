class Tag
  include Mongoid::Document

  field :name
  belongs_to :account
  references_and_referenced_in_many :contacts

  validates :name, :presence => true
  validates :account, :presence => true

  validates_uniqueness_of :name, :scope => :account_id

  def self.remove_all_empty
    non_associated_tags = Tag.where(:contact_ids => nil, :contact_ids => [])
    non_associated_tags.delete_all
  end

  def as_json(options = nil)
    options = {} if options.nil?
    json = super options.merge({except: :account_id, methods: [:account_name]})
  end

  def account_name
    account.try :name
  end
end