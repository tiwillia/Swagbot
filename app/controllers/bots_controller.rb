class BotsController < ApplicationController

  before_filter :require_loggedin, :except => :say
  require 'bothandler'

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
      @bot.create_bot_config(bot_id: @bot.id, 
                             channels: [bot_params[:channel]], 
                             operators: [],
                             ncq_watch_plates: ["Cloud Prods & Envs"],
                             ignored_users: ["unifiedbot"])
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
    BOT_HANDLER.enqueue({:bot_id => @bot.id, :action => "start"})
    flash[:success] = "#{@bot.nick} queued to start."
    redirect_to bot_path(@bot)
  end

  def stop
    @bot = Bot.find(params[:id])
    BOT_HANDLER.enqueue({:bot_id => @bot.id, :action => "stop"})
    flash[:success] = "#{@bot.nick} queued to stop."
    redirect_to bot_path(@bot)
  end

  def force_stop
    @bot = Bot.find(params[:id])
    BOT_HANDLER.enqueue({:bot_id => @bot.id, :action => "stop", :force => true})
    flash[:success] = "#{@bot.nick} queued to forcefully stop."
    redirect_to bot_path(@bot)
  end

  def restart
    @bot = Bot.find(params[:id]) 
    BOT_HANDLER.enqueue({:bot_id => @bot.id, :action => "restart"})
    flash[:success] = "#{@bot.nick} queued to restart."
    redirect_to bot_path(@bot)
  end

  def say
    @bot = Bot.find(params[:id])
    if params[:pw] == CONFIG[:admin_password]
      BOT_HANDLER.enqueue({:bot_id => @bot.id, :action => "say", :message => params[:message]})
      respond_to do |format|
        format.json { render :json => {"report" => "Message sent!"} }
      end
    else
      respond_to do |format|
        format.json { render :json => {"report" => "UNAUTHORIZED"} }
      end
    end
  end

  private

  def require_loggedin
    redirect_to '/login' unless logged_in?
  end

  def bot_params
    params.require(:bot).permit!
  end

end
