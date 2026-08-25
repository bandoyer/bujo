require "test_helper"

# The sans-hand mono slot used to drop its face and leave JetBrains Mono
# visible on every metadata row. The token is the one source of that rule, so
# this reads the stylesheet rather than waiting on a computed-style probe.
class LetteringTokensTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/stylesheets/application.css")

  test "every named hand puts its face first on the mono stack" do
    stylesheet = STYLESHEET.read
    faces = {
      "rock-salt" => "Rock Salt",
      "architects-daughter" => "Architects Daughter",
      "patrick-hand" => "Patrick Hand",
      "gochi-hand" => "Gochi Hand",
      "sans" => "Public Sans"
    }

    faces.each do |hand, face|
      block = stylesheet[/\:root\[data-hand="#{Regexp.escape(hand)}"\]\s*\{[^}]+\}/m]
      assert block, "missing :root[data-hand=\"#{hand}\"] token block"
      assert_match(
        /--font-mono:\s*"#{Regexp.escape(face)}",\s*var\(--font-mono-fallback\)/,
        block,
        "the #{hand} hand must put #{face} in front of the mono stack"
      )
    end

    assert_match(
      /--font-mono:\s*"Permanent Marker",\s*var\(--font-mono-fallback\)/,
      stylesheet,
      "the default marker hand must put Permanent Marker in front of the mono stack"
    )
  end
end
