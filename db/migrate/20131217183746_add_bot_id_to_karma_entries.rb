class AddBotIdToKarmaEntries < ActiveRecord::Migration
  def change
    add_column :karma_entries, :bot_id, :integer
  end
end
