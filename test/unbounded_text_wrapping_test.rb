require "test_helper"

# Collection Topics are unbounded. Their T4 owner remains in legacy until the
# Collection page checkpoint; Entry wrapping is exercised in the browser lane.
class UnboundedTextWrappingTest < ActiveSupport::TestCase
  STYLESHEET = Rails.root.join("app/assets/tailwind/legacy.css")

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
end
