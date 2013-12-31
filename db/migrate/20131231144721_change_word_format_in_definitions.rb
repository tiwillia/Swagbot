class ChangeWordFormatInDefinitions < ActiveRecord::Migration
  def change
    change_column :definitions, :word, :string
  end
end
