class BotConfig < ActiveRecord::Base
  # attr_accessible :bot_id, :echo_all_definitions, :karma_timeout
  
  belongs_to :bot

  serialize :channels 
  serialize :operators
  serialize :ncq_watch_plates
end
