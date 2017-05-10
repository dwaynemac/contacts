class CreateAccountContacts < ActiveRecord::Migration
  def change
  	create_table :account_contacts do |t|
  		t.belongs_to :account, :index => true
  		t.belongs_to :contact, :index => true

  		t.string :local_teacher_username

  		t.timestamps
  	end
  end
end
