# frozen_string_literal: true

# Every way the start of an Irish word can be spelled, so search can find a word
# however it is mutated. The rules are data, in config/irish_mutations.yml.
# Search only: nothing stored is changed.
#
#   IrishMutations.new.forms("bean")   # => ["bean", "bhean", "mbean"]
#   IrishMutations.new.forms("bhean")  # => ["bhean", "bean", "mbean"]
class IrishMutations
  RULES = YAML.load_file(Rails.root.join("config/irish_mutations.yml")).freeze
  VOWELS = "aeiouáéíóú"
  # Single letters are particles or initials; their forms would match almost anything.
  MIN_LENGTH = 2

  def initialize(rules = RULES)
    @consonants = rules.fetch("consonants")
    @vowel_prefixes = rules.fetch("vowel_prefixes")
  end

  # The word as typed first, then its other spellings.
  def forms(word)
    word = word.downcase
    return [word] if word.length < MIN_LENGTH

    ([word, *own_mutations(word)] + roots(word).flat_map { |root| [root, *mutations(root)] }).uniq
  end

  private

  attr_reader :consonants, :vowel_prefixes

  # A word that already starts mutated (bhean) is not mutated again (bhhean).
  def own_mutations(word)
    consonant_mutation(word) ? [] : mutations(word)
  end

  # What the word would be with its mutation taken off.
  def roots(word)
    [without_consonant_mutation(word), *without_vowel_prefix(word)].compact
  end

  # The longest mutated spelling the word starts with, as [letter, spelling]:
  # bhfear is f eclipsed, not b lenited.
  def consonant_mutation(word)
    consonants.flat_map { |letter, spellings| spellings.map { |spelling| [letter, spelling] } }
      .select { |_letter, spelling| word.start_with?(spelling) }
      .max_by { |_letter, spelling| spelling.length }
  end

  def without_consonant_mutation(word)
    letter, spelling = consonant_mutation(word)
    letter + word.delete_prefix(spelling) if spelling && word.length > spelling.length
  end

  def without_vowel_prefix(word)
    vowel_prefixes.select { |prefix| word.start_with?(prefix) && vowel?(word[prefix.length]) }
      .map { |prefix| word.delete_prefix(prefix) }
  end

  def mutations(root)
    consonant_forms = consonants.fetch(root[0], []).map { |spelling| spelling + root[1..] }
    vowel_forms = vowel?(root[0]) ? vowel_prefixes.map { |prefix| prefix + root } : []
    consonant_forms + vowel_forms
  end

  def vowel?(letter)
    letter.present? && VOWELS.include?(letter)
  end
end
