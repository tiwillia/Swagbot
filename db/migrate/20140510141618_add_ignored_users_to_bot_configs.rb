class AddIgnoredUsersToBotConfigs < ActiveRecord::Migration

  def change
    add_column :bot_configs, :ignored_users, :text
  end

end
