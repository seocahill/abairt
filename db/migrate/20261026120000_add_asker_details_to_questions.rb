class AddAskerDetailsToQuestions < ActiveRecord::Migration[8.1]
  def change
    # Questions asked through the API (the Mayo Irish course) are asked as the
    # API user on behalf of someone else: asked_via says which way it came in,
    # asker_label who actually asked.
    add_column :questions, :asked_via, :string, null: false, default: "abairt"
    add_column :questions, :asker_label, :string
  end
end
