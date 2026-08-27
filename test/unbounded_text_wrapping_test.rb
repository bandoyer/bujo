require "test_helper"

# Topics and entry text are unbounded. Overflow-wrap is the one rule that keeps
# them inside the viewport; reading the stylesheet pins it without a browser.
class UnboundedTextWrappingTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/tailwind/legacy.css")

  test "entry text and destination meta wrap anywhere instead of truncating" do
    stylesheet = STYLESHEET.read
    rule = stylesheet[/\.entry__text,\s*\.entry__meta\s*\{[^}]+\}/m]

    assert rule, "missing the shared wrap rule for .entry__text and .entry__meta"
    assert_no_match(/text-overflow:\s*ellipsis/, rule,
      "wrapping must not trade overflow for a truncated Topic")
    assert_no_match(/overflow:\s*hidden/, rule,
      "wrapping must not hide characters to contain the row")
    assert_match(/min-width:\s*0/, rule,
      "wrapping columns must be allowed to shrink below their content size")
    assert_match(/overflow-wrap:\s*anywhere/, rule,
      "an unbounded Topic or entry text must wrap instead of widening the row")
  end

  test "Collection heading and Index links wrap unbounded Topics" do
    stylesheet = STYLESHEET.read
    heading = stylesheet[/\.collection-page__heading h1\s*\{[^}]+\}/m]
    index_link = stylesheet[/\.collection-index__topic-link\s*\{[^}]+\}/m]

    assert heading, "missing .collection-page__heading h1 rule"
    assert index_link, "missing .collection-index__topic-link rule"
    assert_match(/overflow-wrap:\s*anywhere/, heading,
      "a Collection Topic in the page heading must wrap instead of widening the screen")
    assert_match(/overflow-wrap:\s*anywhere/, index_link,
      "an Index Topic must wrap instead of widening the screen")
  end

  test "the entry line keeps a shrinkable text track" do
    stylesheet = STYLESHEET.read
    line = stylesheet[/\.entry__line\s*\{[^}]+\}/m]

    assert line, "missing .entry__line rule"
    assert_match(/minmax\(0,\s*1fr\)/, line,
      "the entry text track must be able to shrink below its content width")
  end
end
