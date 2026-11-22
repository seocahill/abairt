require "test_helper"

class IrishMutationsTest < ActiveSupport::TestCase
  setup do
    @mutations = IrishMutations.new
  end

  test "a plain word also has its lenited and eclipsed spellings" do
    assert_equal %w[bean bhean mbean], @mutations.forms("bean")
    assert_equal %w[fear fhear bhfear], @mutations.forms("fear")
  end

  test "a mutated word also has its plain spelling and the other mutations" do
    assert_equal %w[bhean bean mbean], @mutations.forms("bhean")
    assert_equal %w[mbean bean bhean], @mutations.forms("mbean")
  end

  test "a mutated word is not mutated again" do
    assert_not_includes @mutations.forms("bhean"), "bhhean"
    assert_not_includes @mutations.forms("bhean"), "mbhean"
  end

  test "the longest mutated spelling is the one taken off" do
    assert_equal %w[bhfear fear fhear], @mutations.forms("bhfear")
  end

  test "a word starting with a vowel takes the joined prefixes, and loses them" do
    assert_equal %w[uisce nuisce huisce tuisce], @mutations.forms("uisce")
    assert_includes @mutations.forms("nuisce"), "uisce"
  end

  test "accented vowels count as vowels" do
    assert_includes @mutations.forms("ól"), "nól"
  end

  test "case does not matter" do
    assert_equal @mutations.forms("bhean"), @mutations.forms("Bhean")
  end

  test "single letters and numbers are left alone" do
    assert_equal %w[a], @mutations.forms("a")
    assert_equal %w[1916], @mutations.forms("1916")
  end

  test "a mutated spelling on its own is not stripped to a single letter" do
    assert_equal %w[bh], @mutations.forms("bh")
  end

  test "the rules come from the table it is given" do
    mutations = IrishMutations.new("consonants" => {"x" => ["xh"]}, "vowel_prefixes" => [])

    assert_equal %w[xab xhab], mutations.forms("xab")
    assert_equal %w[bean], mutations.forms("bean")
  end

  test "every rule in the table is lowercase letters" do
    rules = IrishMutations::RULES
    spellings = rules.fetch("consonants").to_a.flatten + rules.fetch("vowel_prefixes")

    assert spellings.all? { |spelling| spelling.match?(/\A[a-z]+\z/) }, spellings.inspect
  end
end
