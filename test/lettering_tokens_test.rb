require "test_helper"

# Pins the readable Bujo token module rather than compiler output. Browser
# coverage separately proves that these source declarations win when rendered.
class LetteringTokensTest < ActiveSupport::TestCase
  TOKEN_SOURCE = Rails.root.join("app/assets/tailwind/tokens.css")
  SEMANTIC_BRIDGE = {
    "--color-page" => "var(--bg)",
    "--color-surface" => "var(--surface)",
    "--color-ink" => "var(--ink)",
    "--color-muted" => "var(--muted)",
    "--color-faint" => "var(--faint)",
    "--color-rule" => "var(--line)",
    "--color-accent" => "var(--accent)",
    "--color-warning" => "var(--warn)",
    "--color-dot" => "var(--dot)",
    "--color-selected-row" => "var(--selected-row)",
    "--color-today-row" => "var(--today-row)",
    "--font-hand" => "var(--font-body)",
    "--font-heading" => "var(--font-serif)",
    "--font-glyph" => "var(--font-mono)"
  }.freeze
  HAND_FACES = {
    "rock-salt" => "Rock Salt",
    "architects-daughter" => "Architects Daughter",
    "patrick-hand" => "Patrick Hand",
    "gochi-hand" => "Gochi Hand",
    "sans" => "Public Sans"
  }.freeze

  test "the inline Tailwind bridge exposes every live Bujo presentation token" do
    source = TOKEN_SOURCE.read
    bridge = declarations_in(source, "@theme inline")

    assert_equal SEMANTIC_BRIDGE, bridge
    assert_equal({ "--*" => "initial" }, declarations_in(source, "@theme"))
    assert_no_match(/--color-(?:red|blue|gray)-|--spacing|--radius-|--shadow-/, source)
  end

  test "default and every named hand put the selected face before glyph fallback" do
    source = TOKEN_SOURCE.read
    root = declarations_in(source, ":root")

    assert_equal font_declarations("Permanent Marker"), root.slice("--font-body", "--font-serif", "--font-mono")
    HAND_FACES.each do |hand, face|
      declarations = declarations_in(source, %(:root[data-hand="#{hand}"]))
      expected = hand == "sans" ? sans_font_declarations : font_declarations(face)
      assert_equal expected, declarations.slice("--font-body", "--font-serif", "--font-mono")
    end
  end

  test "dark values have one literal source and both precedence paths reference it" do
    source = TOKEN_SOURCE.read
    root = declarations_in(source, ":root")
    dark_values = root.select { |name, _value| name.start_with?("--dark-") }

    assert_equal 8, dark_values.size
    dark_values.each_value { |value| assert_equal 1, source.scan(value).size }
    [ ':root:not([data-theme="light"])', ':root[data-theme="dark"]' ].each do |selector|
      applied = declarations_in(source, selector)
      %w[bg surface ink muted line accent warn].each do |name|
        assert_equal "var(--dark-#{name})", applied.fetch("--#{name}")
      end
      assert_equal "var(--dark-muted)", applied.fetch("--faint")
      assert_equal "dark", applied.fetch("color-scheme")
    end
  end

  private

  def declarations_in(source, selector, occurrence: 1)
    matches = source.to_enum(:scan, /#{Regexp.escape(selector)}\s*\{([^{}]*)\}/m).map { Regexp.last_match(1) }
    body = matches.fetch(occurrence - 1) { flunk "missing #{selector} declaration block" }
    body.scan(/([\w*-]+)\s*:\s*([^;]+);/).to_h.transform_values(&:strip)
  end

  def font_declarations(face)
    {
      "--font-body" => %("#{face}", var(--font-body-fallback)),
      "--font-serif" => %("#{face}", var(--font-serif-fallback)),
      "--font-mono" => %("#{face}", var(--font-mono-fallback))
    }
  end

  def sans_font_declarations
    {
      "--font-body" => '"Public Sans", var(--font-body-fallback)',
      "--font-serif" => '"Public Sans", var(--font-body-fallback)',
      "--font-mono" => '"Public Sans", var(--font-mono-fallback)'
    }
  end
end
