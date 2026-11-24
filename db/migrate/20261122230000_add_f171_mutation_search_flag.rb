# Registers the flag, switched off, so it shows in the /flipper list.
class AddF171MutationSearchFlag < ActiveRecord::Migration[8.1]
  def up
    Flipper.add(:f171_mutation_search)
  end

  def down
    Flipper.remove(:f171_mutation_search)
  end
end
