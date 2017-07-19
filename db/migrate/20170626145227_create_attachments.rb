class CreateAttachments < ActiveRecord::Migration
  def change
  	create_table :attachments do |t|
  		t.belongs_to :account, index: true
  		t.string :contact_id, limit: 24, index: true

  		t.boolean :public, default: false
      	t.string :name
      	t.text :description
      	t.string :file

      	t.timestamps
  	end
  end
end
