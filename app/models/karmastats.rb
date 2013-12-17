class Karmastats < ActiveRecord::Base
  self.table_name = "karmastats"
  
  belongs_to :bot
end
