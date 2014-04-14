class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def create_bot_controls(bot_id)
    if not defined? @@bot_controls
      @@bot_controls = Hash.new
      if not Bot.all.empty?
        Bot.all.each do |bot|
          @@bot_controls[bot.id] = Hash[ :thread => nil, :queue => Queue.new, :state => "stopped" ]  
        end
      end
    end
    if @@bot_controls[bot_id]
      if not defined? @@bot_controls[bot_id][:thread]
        @@bot_controls[bot_id][:thread] = nil
      end
    else
      @@bot_controls[bot_id] = Hash[ :thread => nil, :queue => Queue.new, :state => "stopped" ]
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
                    :nickserv_password => bot.nickserv_password,
                    :bot => bot
                 }
        Rails.logger.info "Creating new bot thread, details:"
        Rails.logger.info params.inspect
        begin
          bot.connect()
        rescue => exception
          Rails.logger.error exception.message
          Rails.logger.error exception.backtrace
        end
        Rails.logger.info "Bot started: " + bot.inspect
        @@bot_controls[bot.id][:state] = "running"
        loop {
          command = @@bot_controls[bot.id][:queue].pop(true) rescue nil
          if command
            case command
            when "start"
              bot.connect
              @@bot_controls[bot.id][:state] = "running"
            when "stop"
              bot.kill
              @@bot_controls[bot.id][:state] = "stopped"
            when "restart"
              bot.kill
              @@bot_controls[bot.id][:state] = "stopped"
              bot.connect
              @@bot_controls[bot.id][:state] = "running"
            end
          else
            begin
              # Run through the loop
              # Also check if we should reconnect
              case bot.loop()
              when "reconnect"
                @@bot_controls[bot.id][:queue] << "restart"
              when "connection lost"
                Rails.logger.error "Lost connection... waiting 30 seconds and retrying."
                sleep 30
                @@bot_controls[bot.id][:queue] << "restart"
              end
            rescue => exception
              Rails.logger.error exception.message
              Rails.logger.error exception.backtrace
            end
          end
        }
      }
      true
    else
      false
    end
  end

def bot_controls
  @@bot_controls
end

helper_method :bot_controls

end
