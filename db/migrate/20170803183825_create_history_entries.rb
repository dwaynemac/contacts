class CreateHistoryEntries < ActiveRecord::Migration
  def change
  	create_table :history_entries do |t|
  		t.string :historiable_type
  		t.string :historiable_id
  		t.string :attr
		  t.string :old_value
		  t.datetime :changed_at
  	end
  end
end
