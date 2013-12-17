class AddKarmaTimeoutToBots < ActiveRecord::Migration
  def change
    add_column :bots, :karma_timeout, :integer
  end
end
