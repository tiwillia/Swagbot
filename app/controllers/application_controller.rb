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
        params = {  :server => bot.server, 
                    :port => bot.port, 
                    :nick => bot.nick, 
                    :channel => bot.channel,
                    :server_password => bot.server_password,
                    :nickserv_password => bot.nickserv_password
                 }
        bot_ob = Swagbot.new(params)
        bot_ob.connect()
        loop {
          command = @@bot_controls[bot.id][:queue].pop(true) rescue nil
          if command
            case command
            when "start"
              bot_ob.connect
              @@bot_controls[bot.id][:state] = "running"
            when "stop"
              bot_ob.kill
              @@bot_controls[bot.id][:state] = "stopped"
            when "restart"
              bot_ob.kill
              @@bot_controls[bot.id][:state] = "stopped"
              bot_ob.connect
              @@bot_controls[bot.id][:state] = "running"
            end
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
