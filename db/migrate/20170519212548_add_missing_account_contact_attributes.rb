class AddMissingAccountContactAttributes < ActiveRecord::Migration
  def change
  	add_column :account_contacts, :coefficient, :integer
  	add_column :account_contacts, :last_seen_at, :datetime
  	add_column :account_contacts, :observation, :text
  end
end
