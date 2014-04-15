class BotsController < ApplicationController

# Simple index
# This should list all bots and
def index
  if not Bot.all.empty?
    @bots = Bot.all
  else
    @bot = Bot.new
    redirect_to new_bot_path(@bot)
  end
end

def show
  @bot = Bot.find(params[:id]) 
end

def edit
  @bot = Bot.find(params[:id])
end

def update
  @bot = Bot.find(params[:id])
  if @bot.update_attributes(bot_params)
    flash[:success] = @bot.nick + ' was successfully updated.'
    redirect_to @bot
  else
    flash[:error] = 'Could not update ' + @bot.nick + '.'
    redirect_to edit_bot_path(@bot)
  end
end

def new
  @bot = Bot.new
end

# Create a new bot
def create
  @bot = Bot.new(bot_params)
  @bot.karma_timeout = 5
  if @bot.save
    @bot.bot_config = BotConfig.new(bot_id: @bot.id, channels: [bot_params[:channel]])
    flash[:success] = @bot.nick + ' successfully created.'
    redirect_to @bot
  else
    flash[:error] = 'Could not create ' + @bot.nick + '.'
    redirect_to new_bot_path
  end
end

def destroy
  @bot = Bot.find(params[:id])
  if @bot.destroy
    flash[:success] = @bot.nick.capitalize + " was successfully deleted."
    redirect_to bots_url
  else
    flash[:error] = "Could not delete " + @bot.nick.capitalize + "."
    redirect_to bot_path(@bot)
  end
end

def start
  @bot = Bot.find(params[:id])
  if @bot.bot_config.nil?
    @bot.bot_config = BotConfig.new(bot_id: @bot.id) 
  end
  check_bot_controls_exist(@bot.id)
  if not @@bot_controls[@bot.id][:thread] 
    if create_bot_thread(@bot)
      flash[:success] = "Started " + @bot.nick.capitalize + "."
    else
      flash[:error] = @bot.nick.capitalize + " is already running."
    end
  else
    if @@bot_controls[@bot.id][:state] == "running"
      flash[:error] = @bot.nick.capitalize + " is already running."
    else
      @@bot_controls[:queue] << "start"
      flash[:success] = "Started " + @bot.nick.capitalize + "."
    end
  end
  redirect_to bot_path(@bot)
end

def stop
  @bot = Bot.find(params[:id])
  check_bot_controls_exist(@bot.id)
  if @@bot_controls[@bot.id][:thread]
    if @@bot_controls[@bot.id][:state] = "running"
      @@bot_controls[@bot.id][:queue] << "stop"
      flash[:success] = "Stopped " + @bot.nick.capitalize + "."
    else
      flash[:error] = @bot.nick.capitalize + " is not currently running."
    end
  else
    flash[:error] = @bot.nick.capitalize + " has never been started."
  end 
  redirect_to bot_path(@bot)
end

def restart
  @bot = Bot.find(params[:id]) 
  check_bot_controls_exist(@bot.id)
  if @@bot_controls[@bot.id][:thread]
    if @@bot_controls[@bot.id][:state] = "running"
      @@bot_controls[@bot.id][:queue] << "restart"
      flash[:success] = "Restarted " + @bot.nick.capitalize + "."
    else
      @@bot_controls[@bot.id][:queue] << "start"
      flash[:success] = @bot.nick.capitalize + " was not running, started bot."
    end
  else
    flash[:error] = @bot.nick.capitalize + " has never been started."
  end 
  redirect_to bot_path(@bot)
end

private
def bot_params
  params.require(:bot).permit!
end

def check_bot_controls_exist(bot_id)
  if not defined? @@bot_controls
    create_bot_controls(bot_id)
  end
  if not @@bot_controls[bot_id]
    create_bot_controls(bot_id)
  end
end

end
