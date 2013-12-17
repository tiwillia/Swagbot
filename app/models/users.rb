class Users < ActiveRecord::Base
  self.table_name = "users"

  belongs_to :bot
end
