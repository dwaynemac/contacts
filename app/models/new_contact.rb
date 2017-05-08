class NewContact < ActiveRecord::Base
	self.table_name = "contacts"
	has_objectid_primary_key
end
