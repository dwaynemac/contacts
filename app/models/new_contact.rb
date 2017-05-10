class NewContact < ActiveRecord::Base
	self.table_name = "contacts"
	has_objectid_primary_key

	has_many :account_contacts
	has_many :accounts, through: :account_contacts, :foreign_key => :contact_id, :class_name => "NewAccount"
	
	belongs_to :owner, :class_name => "NewAccount"

	validates :first_name, :presence => true
end
