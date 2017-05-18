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

ActiveRecord::Schema.define(:version => 20170516191833) do

  create_table "account_contacts", :force => true do |t|
    t.integer  "account_id"
    t.string   "contact_id",             :limit => 24
    t.string   "local_teacher_username"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "local_status"
  end

  create_table "accounts", :force => true do |t|
    t.string "name"
  end

  create_table "contact_attributes", :force => true do |t|
    t.string  "type"
    t.integer "account_id"
    t.string  "contact_id",   :limit => 24
    t.boolean "primary",                    :default => false
    t.boolean "public",                     :default => false
    t.string  "category"
    t.string  "string_value"
    t.date    "date_value"
    t.string  "postal_code"
    t.string  "city"
    t.string  "state"
    t.string  "neighborhood"
    t.string  "country"
  end

  create_table "contacts", :force => true do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "owner_id"
    t.string   "status"
  end

  add_index "contacts", ["id"], :name => "index_contacts_on_id", :unique => true

end
