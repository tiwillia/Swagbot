class AddQuoteIdToQuotes < ActiveRecord::Migration

  def change
    add_column :quotes, :bot_specific_quote_id, :integer
  end

end
