class BotConfigController < ApplicationController

  def edit
    @bot = Bot.find(params[:id])
    @bot_config = @bot.bot_config
  end
  
  def update
    @bot = Bot.find(params[:id])
    if @bot.bot_config.update_attributes(config_params)
      flash[:success] = @bot.nick + ' was successfully updated.'
      redirect_to @bot
    else
      flash[:error] = 'Could not update ' + @bot.nick + '.'
      redirect_to edit_bot_path(@bot)
    end 
  end

private
  def config_params
    params.permit(:quit_message, :karma_timeout, :echo_all_definitions, :id)
  end

end
