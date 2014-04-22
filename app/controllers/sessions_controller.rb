class SessionsController < ApplicationController

  def new
  end
  
  def create
    session[:password] = params[:password]
    if logged_in?
      flash[:success] = "Successfully logged in"
      redirect_to '/welcome/index'
    else
      reset_session
      flash[:error] = "Login Failed"
      redirect_to '/login'
    end
  end

  def destroy
    reset_session
    flash[:success] = "Logged out"
    redirect_to '/welcome/index'
  end

end
