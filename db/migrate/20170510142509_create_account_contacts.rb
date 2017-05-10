class CreateAccountContacts < ActiveRecord::Migration
  def change
  	create_table :account_contacts do |t|
  		t.belongs_to :account, :index => true
  		t.string :contact_id, limit: 24, :index => true

  		t.string :local_teacher_username

  		t.timestamps
  	end
  end
end
