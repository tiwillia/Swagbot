class AddWeatherConfigsToBotConfigs < ActiveRecord::Migration

  def change
    add_column :bot_configs, :weather, :boolean, :default => true
    add_column :bot_configs, :default_weather_zip, :integer, :default => 27606
  end

end
