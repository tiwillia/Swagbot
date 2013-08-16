#!/usr/bin/env ruby

class KarmaStats < ActiveRecord::Base

self.table_name = "karmastats"

def get(user_id)
  total = 0
  Karma.find_each(recipient_id: user_id) do |k|
    total = (total + k.amount)
  end
  total 
end

end
