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

ActiveRecord::Schema.define(:version => 20140506192225) do

  create_table "bot_configs", :force => true do |t|
    t.integer  "bot_id"
    t.integer  "karma_timeout",        :default => 5
    t.boolean  "echo_all_definitions", :default => true
    t.datetime "created_at",                                     :null => false
    t.datetime "updated_at",                                     :null => false
    t.string   "quit_message",         :default => "Leaving..."
    t.boolean  "quotes",               :default => true
    t.boolean  "definitions",          :default => true
    t.boolean  "karma",                :default => true
    t.boolean  "youtube",              :default => true
    t.boolean  "imgur",                :default => true
    t.boolean  "bugzilla",             :default => true
    t.text     "channels"
    t.integer  "num_of_karma_ranks",   :default => 5
    t.boolean  "weather",              :default => true
    t.integer  "default_weather_zip",  :default => 27606
    t.boolean  "operator_control",     :default => true
    t.boolean  "operator_any_user",    :default => true
    t.text     "operators"
  end

  create_table "bots", :force => true do |t|
    t.string   "nick"
    t.string   "channel"
    t.datetime "created_at",        :null => false
    t.datetime "updated_at",        :null => false
    t.string   "server"
    t.integer  "port"
    t.string   "server_password"
    t.string   "nickserv_password"
    t.integer  "karma_timeout"
  end

  create_table "definitions", :force => true do |t|
    t.integer  "recorder_id"
    t.string   "word"
    t.text     "definition"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "bot_id"
  end

  create_table "karma_entries", :force => true do |t|
    t.integer  "grantor_id"
    t.integer  "recipient_id"
    t.integer  "amount"
    t.datetime "created_at",   :null => false
    t.datetime "updated_at",   :null => false
    t.integer  "bot_id"
  end

  create_table "karmastats", :force => true do |t|
    t.integer  "user_id"
    t.integer  "total"
    t.integer  "rank"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer  "bot_id"
  end

  create_table "quotes", :force => true do |t|
    t.integer  "recorder_id"
    t.integer  "quotee_id"
    t.text     "quote"
    t.datetime "created_at",  :null => false
    t.datetime "updated_at",  :null => false
    t.integer  "bot_id"
  end

  create_table "users", :force => true do |t|
    t.string   "user"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
    t.integer  "bot_id"
  end

end
