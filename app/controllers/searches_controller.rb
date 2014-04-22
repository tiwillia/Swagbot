class SearchesController < ApplicationController

before_filter :require_loggedin

  def definitions
    bot = Bot.find(bot_id)
    search do 
      defs = bot.definitions.where("definition like ?", "%#{search_params}%")
      words = bot.definitions.where("word like ?", "%#{search_params}%")
      (defs + words).uniq
    end
  end

  def quotes
    bot = Bot.find(bot_id)
    search do
      quotes = bot.quotes.where("quote like ?", "%#{search_params}%").to_a
      bot.users.where("user like ?", "%#{search_params}%").each do |user|
        quotees = bot.quotes.find_by_quotee_id(user.id)
        quotes << quotees if quotees
      end
      quotes.uniq.sort! {|x,y| x.id <=> y.id }
    end
  end

  def karma
    bot = Bot.find(bot_id)
    search do
      user = bot.users.find_by_user(search_params)
      bot.karmastats.find_by_user_id(user.id)
    end
  end

private

  def search(&block)
    if search_params
      if block_given?
        @results = yield
        @search_query = search_params
        if @results.empty?
          flash[:error] = "No records found for \"" + @search_query + "\"."
          redirect_to :back
        end  
      else 
        flash[:error] = "Some serious shit just went down on the backend."
        redirect_to root_url
      end
    else
      flash[:error] = "No search query specified."
      redirect_to :back
    end
  end  

  def bot_id
    params.require("bot_id")
    params[:bot_id]
  end

  def search_params
    params.require("query")
    params[:query]
  end

  def require_loggedin
    redirect_to '/login' unless logged_in?
  end

end
