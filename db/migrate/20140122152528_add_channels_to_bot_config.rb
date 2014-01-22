class AddChannelsToBotConfig < ActiveRecord::Migration
  def change
    add_column :bot_configs, :channels, :text
  end
end
