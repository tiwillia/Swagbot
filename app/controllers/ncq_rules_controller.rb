class NcqRulesController < ApplicationController

  def create
    @ncq_rule = NcqRule.new(ncq_params)
    if @ncq_rule.save
      flash[:success] = "NCQ watcher rule added."
      redirect_to :back
    else
      flash[:error] = "NCQ watcher rule could not be created."
      redirect_to :back
    end
  end

  def destroy
    @ncq_rule = NcqRule.find(params[:id])
    if @ncq_rule.destroy
      flash[:success] = "NCQ watcher rule destroyed."
      redirect_to :back
    else
      flash[:error] = "NCQ watcher rule could not be destroyed."
      redirect_to :back
    end
  end

private

  def ncq_params
    params.require(:ncq_rule).permit(:match_string, :search_type, :use_default_ping_term, :ping_term, :bot_id)
  end

end
