class AddNumOfKarmaRanksToBotConfig < ActiveRecord::Migration
  def change
    add_column :bot_configs, :num_of_karma_ranks, :integer, :default => 5
  end
end
