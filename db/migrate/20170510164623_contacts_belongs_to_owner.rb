class ContactsBelongsToOwner < ActiveRecord::Migration
  def change
  	add_column :contacts, :owner_id, :integer, references: "accounts", index: true
  end
end
