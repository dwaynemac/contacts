class CreateMerges < ActiveRecord::Migration
  def change
  	create_table :merges do |t|
  		t.string :father_id, limit: 24, index: true
  		t.string :son_id, limit: 24, index: true
  		t.string :first_contact_id, limit: 24, index: true
  		t.string :second_contact_id, limit: 24, index: true
  		t.text :services
  		t.text :warnings
  		t.text :messages
  		t.string :state
  	end
  end
end
