class CreateContactAttributes < ActiveRecord::Migration
  def change
  	create_table :contact_attributes do |t|
  		t.string :type, index: true

  		t.belongs_to :account, index: true
  		t.string :contact_id, limit: 24, index: true

  		t.boolean :primary, default: false
  		t.boolean :public, default: false

  		t.string :category
  		t.string :string_value
  		t.date :date_value
  		t.string :postal_code
  		t.string :city
  		t.string :state
  		t.string :neighborhood
  		t.string :country
  	end
  end
end
