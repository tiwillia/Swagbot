
require 'rubygems'
require 'active_record'
require 'yaml'
require 'pg'

  dbconfig = YAML::load(File.open('/home/tiwillia/Projects/swagbot/config/database.yml'))
#  ActiveRecord::Base.establish_connection(dbconfig)
  ActiveRecord::Base.connection.create_database(dbconfig.fetch('database'))
  ActiveRecord::Base.establish_connection(dbconfig)

  ActiveRecord::Migrator.migrate "/home/tiwillia/Projects/swagbot/db/migrate/", ARGV[0] ? ARGV[0].to_i : nil
