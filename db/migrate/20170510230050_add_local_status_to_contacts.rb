class AddLocalStatusToContacts < ActiveRecord::Migration
  def change
  	add_column :account_contacts, :local_status, :string
  end
end
