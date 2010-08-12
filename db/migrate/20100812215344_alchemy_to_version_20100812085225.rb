class AlchemyToVersion20100812085225 < ActiveRecord::Migration
  def self.up
    Engines.plugins["alchemy"].migrate(20100812085225)
  end

  def self.down
    Engines.plugins["alchemy"].migrate(20100709163925)
  end
end
