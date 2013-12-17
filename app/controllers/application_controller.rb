class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def create_bot_controls(bot_id)
    if not defined? @@bot_controls
      @@bot_controls = Array.new
    end
    if @@bot_controls[bot_id]
      @@bot_controls[bot_id]
    else
      @@bot_controls[bot_id]= Hash[ :thread => nil, :queue => Queue.new, :state => "stopped" ]
      @@bot_controls[bot_id]
    end
  end

  def create_bot_thread(bot) 
    if not @@bot_controls[bot.id][:thread]
      @@bot_controls[bot.id][:thread] = Thread.new {
        bot_ob = Swagbot.new(bot.server, bot.port, bot.nick, bot.channel)
        bot_ob.connect()
        loop {
          command = @@bot_controls[bot.id][:queue].pop(true) rescue nil
          if command
            puts "queue popped for some reason?"
            puts command
          else
            puts bot_ob.inspect
            bot_ob.loop()
          end
        }
      }
      true
    else
      false
    end
  end

end
