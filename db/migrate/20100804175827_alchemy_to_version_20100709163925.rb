class AlchemyToVersion20100709163925 < ActiveRecord::Migration
  def self.up
    Engines.plugins["alchemy"].migrate(20100709163925)
  end

  def self.down
    Engines.plugins["alchemy"].migrate(0)
  end
end
