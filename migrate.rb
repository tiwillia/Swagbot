# NOTE:
# The database must be created first. You can follow the steps below to create it:
# 1) Install postgresql and the pg gem
# 2) start the postgresql-9.2 service and chkconfig it on
# 3) su - root
# 4) su - postgres
# 5) psql
# 6) CREATE USER <user> WITH PASSWORD '<password>';
# 7) CREATE DATABASE <database>;
# 8) GRANT ALL PRIVILEGES ON DATABASE <database> <user>;
# 9) \q
#
# Also note, the above paramters must be configured properly in config/database.yml
# All migration files are located in db/migrate

require 'rubygems'
require 'active_record'
require 'yaml'
require 'pg'

  dbconfig = YAML::load(File.open('config/database.yml'))
  ActiveRecord::Base.establish_connection(dbconfig)
  ActiveRecord::Migrator.migrate "/db/migrate/", ARGV[0] ? ARGV[0].to_i : nil
