class CreateComhras < ActiveRecord::Migration[6.1]
  def change
    create_table :comhras do |t|

      t.timestamps
    end
  end
end
