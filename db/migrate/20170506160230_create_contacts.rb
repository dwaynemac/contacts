class CreateContacts < ActiveRecord::Migration
  def change
  	create_table :contacts, id: false do |t|
  		t.string :id, limit: 24, null: false, primary: true
  		t.string :first_name
  		t.string :last_name
  		t.timestamps
  	end
  	add_index :contacts, :id, unique: true
  end
end
