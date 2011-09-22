class List
  include Mongoid::Document

  field :name

  belongs_to :account
  references_and_referenced_in_many :contacts

  validates :name, :presence => true
  validates :account, :presence => true
end