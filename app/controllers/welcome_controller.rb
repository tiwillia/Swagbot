class WelcomeController < ApplicationController
  
  def index
    if not logged_in?
      redirect_to '/login'
    end
  end

  def login
  end

end
