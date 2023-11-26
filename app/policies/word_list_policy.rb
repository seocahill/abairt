class WordListPolicy < ApplicationPolicy
  def update?
    user == record.owner
  end

  def destroy?
    user == record.owner
  end
end
