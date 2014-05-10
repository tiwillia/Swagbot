class BotConfigController < ApplicationController

before_filter :require_loggedin

  def edit
    @bot = Bot.find(params[:id])
    @bot_config = @bot.bot_config
  end
  
  def update
    @bot = Bot.find(params[:id])
    parsed_params = config_params
    parsed_params[:channels] = config_params[:channels].split(",")
    parsed_params[:operators] = config_params[:operators].split(",")
    parsed_params[:ncq_watch_plates] = config_params[:ncq_watch_plates].split(",")
    if @bot.bot_config.update_attributes(parsed_params)
      flash[:success] = @bot.nick + ' was successfully updated.'
      redirect_to @bot
    else
      flash[:error] = 'Could not update ' + @bot.nick + '.'
      redirect_to edit_bot_path(@bot)
    end 
  end

private
  def config_params
    params.permit(:karma, :quotes, :definitions, :youtube, :bugzilla, :imgur, :quit_message, :karma_timeout, :echo_all_definitions, :id, :channels, :num_of_karma_ranks, :weather, :default_weather_zip, :operators, :operator_any_user, :operator_control, :ncq_watcher, :ncq_watch_plates, :ncq_watch_interval, :ncq_watch_ping_term, :ncq_watch_details, :ignored_users)
  end

  def require_loggedin
    redirect_to '/login' unless logged_in?
  end

end
