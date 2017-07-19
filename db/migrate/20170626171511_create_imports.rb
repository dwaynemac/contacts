class CreateImports < ActiveRecord::Migration
  def change
  	create_table :imports do |t|
  		t.belongs_to :account, index: true
  		t.belongs_to :attachment
  		t.string :status
  		t.text :failed_rows
  		t.text :headers
  	end

  	create_table :contact_imports do |t|
      t.string :contact_id, limit: 24, index: true
      t.belongs_to :import, index: true
    end

    add_index :contact_imports, [:contact_id, :import_id]
  end
end
