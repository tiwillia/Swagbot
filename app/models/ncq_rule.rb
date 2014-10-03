class NcqRule < ActiveRecord::Base

  belongs_to :bot

  validates :match_string, :search_type, presence: true

end
