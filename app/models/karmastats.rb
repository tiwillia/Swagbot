#!/usr/bin/env ruby

class KarmaStats < ActiveRecord::Base

self.table_name = "karmastats"

# This following method is unused, but is a remnant of another way
# to do this. Or something. idk. Brain = fried.
=begin
def get(user_id)
  total = 0
  Karma.find_each(recipient_id: user_id) do |k|
    total = (total + k.amount)
  end
  total 
end
=end

end
