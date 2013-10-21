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
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20130821012700) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "bots", force: true do |t|
    t.string   "nick"
    t.string   "channel"
    t.string   "irc_file"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "definitions", force: true do |t|
    t.integer  "recorder_id"
    t.text     "word"
    t.text     "definition"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "karma", force: true do |t|
    t.integer  "grantor_id"
    t.integer  "recipient_id"
    t.integer  "amount"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "karmastats", force: true do |t|
    t.integer  "user_id"
    t.integer  "total"
    t.integer  "rank"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "quotes", force: true do |t|
    t.integer  "recorder_id"
    t.integer  "quotee_id"
    t.text     "quote"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "users", force: true do |t|
    t.text     "user"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
