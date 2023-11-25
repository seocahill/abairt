class WordListPolicy < ApplicationPolicy
  def update?
    user == record.owner
  end
end
