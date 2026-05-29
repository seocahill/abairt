class AddScriptToWordList < ActiveRecord::Migration[7.0]
  def change
    add_column :word_lists, :script, :text
  end
end
