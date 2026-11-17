# frozen_string_literal: true

# Plain-English descriptions of Flipper flags, kept in
# config/flipper_descriptions.yml, with a link to the issue built from the
# number in the flag name (f<issue>_<slug>).
class FlipperDescriptions
  ISSUE_URL = "https://github.com/seocahill/abairt/issues/%s"

  def initialize(path = Rails.root.join("config/flipper_descriptions.yml"))
    @path = path
  end

  def descriptions
    YAML.safe_load_file(@path) || {}
  end

  def issue_url(flag)
    number = flag.to_s[/\Af(\d+)_/, 1]
    format(ISSUE_URL, number) if number
  end

  # Shape expected by Flipper::UI's descriptions_source: {"flag" => "html"}.
  # The list page strips links, so the URL is also shown as plain text there.
  def for_ui(keys)
    descriptions.slice(*keys.map(&:to_s)).to_h do |flag, text|
      url = issue_url(flag)
      html = ERB::Util.html_escape(text)
      html = "#{html} <a href=\"#{url}\">#{url}</a>".html_safe if url
      [flag, html.to_str]
    end
  end
end
