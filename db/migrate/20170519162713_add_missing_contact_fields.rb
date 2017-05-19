class AddMissingContactFields < ActiveRecord::Migration
  def change
  	add_column :contacts, :gender, :string
  	add_column :contacts, :level, :integer
  	add_column :contacts, :in_professional_training, :boolean
  	add_column :contacts, :professional_training_level, :integer
  	add_column :contacts, :first_enrolled_on, :date
  	add_column :contacts, :normalized_first_name, :string
  	add_column :contacts, :normalized_last_name, :string
  	add_column :contacts, :estimated_age, :integer
  	add_column :contacts, :estimated_age_on, :date
  	add_column :contacts, :derose_id, :string
  	add_column :contacts, :kshema_id, :integer
  	add_column :contacts, :publish_on_gdp, :boolean
  	add_column :contacts, :global_teacher_username, :string
  end
end
