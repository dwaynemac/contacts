class AddStatusToContacts < ActiveRecord::Migration
  def change
  	add_column :contacts, :status, :string
  end
end
