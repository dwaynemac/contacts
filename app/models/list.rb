class List
  include Mongoid::Document

  field :name

  belongs_to :account
  has_and_belongs_to_many :contacts

  validates :name, :presence => true
  validates :account, :presence => true

  validates_uniqueness_of :name, :scope => :account_id
end
