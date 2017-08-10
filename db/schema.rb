# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20170803183825) do

  create_table "account_contacts", :force => true do |t|
    t.integer  "account_id"
    t.string   "contact_id",             :limit => 24
    t.string   "local_teacher_username"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "local_status"
    t.integer  "coefficient"
    t.datetime "last_seen_at"
    t.text     "observation"
  end

  create_table "accounts", :force => true do |t|
    t.string "name"
  end

  create_table "attachments", :force => true do |t|
    t.integer  "account_id"
    t.string   "contact_id",  :limit => 24
    t.boolean  "public",                    :default => false
    t.string   "name"
    t.text     "description"
    t.string   "file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "contact_attributes", :force => true do |t|
    t.string  "type"
    t.integer "account_id"
    t.string  "contact_id",   :limit => 24
    t.boolean "primary",                    :default => false
    t.boolean "public",                     :default => false
    t.string  "category"
    t.string  "string_value"
    t.integer "day"
    t.integer "month"
    t.integer "year"
    t.string  "postal_code"
    t.string  "city"
    t.string  "state"
    t.string  "neighborhood"
    t.string  "country"
  end

  create_table "contact_imports", :force => true do |t|
    t.string  "contact_id", :limit => 24
    t.integer "import_id"
  end

  add_index "contact_imports", ["contact_id", "import_id"], :name => "index_contact_imports_on_contact_id_and_import_id"

  create_table "contacts", :force => true do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "owner_id"
    t.string   "status"
    t.string   "gender"
    t.integer  "level"
    t.boolean  "in_professional_training"
    t.integer  "professional_training_level"
    t.date     "first_enrolled_on"
    t.string   "normalized_first_name"
    t.string   "normalized_last_name"
    t.integer  "estimated_age"
    t.date     "estimated_age_on"
    t.string   "derose_id"
    t.integer  "kshema_id"
    t.boolean  "publish_on_gdp"
    t.string   "global_teacher_username"
    t.string   "avatar"
  end

  add_index "contacts", ["id"], :name => "index_contacts_on_id", :unique => true

  create_table "history_entries", :force => true do |t|
    t.string   "historiable_type"
    t.string   "historiable_id"
    t.string   "attr"
    t.string   "old_value"
    t.datetime "changed_at"
  end

  create_table "imports", :force => true do |t|
    t.integer "account_id"
    t.integer "attachment_id"
    t.string  "status"
    t.text    "failed_rows"
    t.text    "headers"
  end

  create_table "merges", :force => true do |t|
    t.string "father_id",         :limit => 24
    t.string "son_id",            :limit => 24
    t.string "first_contact_id",  :limit => 24
    t.string "second_contact_id", :limit => 24
    t.text   "services"
    t.text   "warnings"
    t.text   "messages"
    t.string "state"
  end

end
