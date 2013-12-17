class AddMoreToBots < ActiveRecord::Migration
  def change
    add_column :bots, :server, :string
    add_column :bots, :port, :integer
    add_column :bots, :server_password, :string
    add_column :bots, :nickserv_password, :string
  end
end
