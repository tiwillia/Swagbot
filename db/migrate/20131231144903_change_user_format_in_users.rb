class ChangeUserFormatInUsers < ActiveRecord::Migration
  def change
    change_column :users, :user, :string
  end
end
