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
  if @bot.update_attributes(thought_params)
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
  if @bot.save
    flash[:success] = @bot.nick + ' successfully created.'
    redirect_to @bot
  else
    flash[:error] = 'Couldn not create ' + @bot.nick + '.'
    redirect_to new_bot_path
  end
end

def start
  @bot = Bot.find(params[:id])
  create_bot_controls(@bot.id)
  if not @@bot_controls[@bot.id][:thread]
    if create_bot_thread(@bot)
      flash[:success] = "Started " + @bot.nick.capitalize
    else
      flash[:error] = @bot.nick.capitalize + " is already running."
    end
  else
    if @@bot_controls[@bot.id][:state] == "running"
      flash[:error] = @bot.nick.capitalize + " is already running."
    else
      bot_control[:queue] << "start"
      flash[:success] = "Started " + @bot.nick.capitalize
    end
  end
  redirect_to bot_path(@bot)
end

def stop
  @bot = Bot.find(params[:id])
  if @@bot_controls[@bot.id][:thread]
    if @@bot_controls[@bot.id][:state] = "running"
      @@bot_controls[@bot.id][:queue] << "stop"
      flash[:success] = "Stopped " + @bot.nick.capitalize
    else
      flash[:error] = @bot.nick.capitalize + " is not currently running"
    end
  else
    flash[:error] = @bot.nick.capitalize + " is not currently running"
  end 
  redirect_to bot_path(@bot)
end

def restart
  @bot = Bot.find(params[:id]) 
end

private
def bot_params
  params.require(:bot).permit!
end

end
