require 'open-uri'
require 'nokogiri'
require 'json'
doc = Nokogiri::HTML.parse(URI.open("https://www.focloir.ie/en/dictionary/ei/#{ARGV.first}"))

res = doc.css("span.sense").map do |node|
  {
    term: node.css("span.EDMEANING").text,
    translations: node.css("span.cit_translation").map { |s| s.css("span.quote").text },
    examples: node.css("span.cit_example").map { |s| s.css("span.quote").text }
  }
end.to_json

puts res