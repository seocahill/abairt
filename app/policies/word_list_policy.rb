class WordListPolicy < ApplicationPolicy
  def update?
    user == record.user
  end

  def destroy?
    user == record.user
  end
end
