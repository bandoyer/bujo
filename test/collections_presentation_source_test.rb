require "test_helper"

# Freezes the T4 Index and Custom Collection declaration boundary. Rendered
# system tests own browser parity; this contract keeps the residual T0 values
# under one readable page owner after legacy removal.
class CollectionsPresentationSourceTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("app/assets/tailwind")
  OWNER = "pages/collections.css"
  T0_STYLESHEET = Rails.root.join("test/fixtures/files/tailwind_v4_t0.css")
  DECLARATION_CONTRACTS = {
    ".collection-page__header" => %w[grid-template-columns],
    ".collection-page__heading" => %w[min-width],
    ".collection-page__heading h1" => %w[overflow-wrap],
    ".collection-page__context" => %w[margin color font-family font-size],
    ".collection-page__button" => %w[display place-items padding border-radius],
    ".collection-page__back" => %w[padding border-radius align-self margin-top],
    ".collection-panel" => %w[padding border-bottom],
    ".collection-form" => %w[display grid-template-columns gap align-items],
    ".collection-form label" => %w[grid-column],
    '.collection-form input[type="text"]' => %w[padding border-radius],
    ".collection-index__topics" => %w[display padding],
    ".collection-index__topic-link" =>
      %w[display min-width align-items border-bottom color overflow-wrap text-decoration],
    ".collection-panel form" => %w[margin],
    ".collection-page > .entry-list" => %w[padding],
    ".collection-page > .daily-log__capture" => %w[display min-height flex flex-direction],
    ".collection-index__create-reveal" => %w[min-height padding border background cursor flex],
    ".collection-page > .daily-log__capture .daily-log__capture-reveal" =>
      %w[min-height padding border background cursor flex],
    ".collection-page > .daily-log__capture .daily-log__capture-reveal .entry-list__empty" => %w[display]
  }.freeze
  T0_SHARED_SELECTORS = {
    ".collection-page > .entry-list" => ".entry-list",
    ".collection-page > .daily-log__capture" => ".daily-log__capture",
    ".collection-page > .daily-log__capture .daily-log__capture-reveal" => ".daily-log__capture-reveal",
    ".collection-page > .daily-log__capture .daily-log__capture-reveal .entry-list__empty" =>
      ".daily-log__capture-reveal .entry-list__empty"
  }.freeze

  test "Index and Collection residual declarations have one page owner" do
    assert_equal 18, DECLARATION_CONTRACTS.size
    assert_equal 52, DECLARATION_CONTRACTS.values.sum(&:size)

    rules = authored_rules
    DECLARATION_CONTRACTS.each do |selector, properties|
      properties.each do |property|
        owners = rules.fetch(selector, []).filter_map do |owner, declarations|
          owner if declarations.assoc(property)
        end.uniq
        assert_equal [ OWNER ], owners, "#{selector} #{property} must live only in #{OWNER}"
      end
    end
  end

  test "Index and Collection residual declarations retain exact T0 values" do
    owner = authored_declarations_for(ROOT.join(OWNER))
    baseline = authored_declarations_for(T0_STYLESHEET)
    assert_equal DECLARATION_CONTRACTS.keys.sort, owner.keys.sort
    assert_equal 52, owner.values.sum(&:size)

    DECLARATION_CONTRACTS.each do |selector, properties|
      baseline_selector = T0_SHARED_SELECTORS.fetch(selector, selector)
      expected = baseline.fetch(baseline_selector).select { |property, _value| property.in?(properties) }
      actual = owner.fetch(selector, [])

      assert_equal properties.sort, expected.map(&:first).sort, "incomplete T0 ledger for #{selector}"
      assert_equal expected.sort, actual.sort, "#{selector} must retain its residual T0 declarations"
    end
  end

  test "legacy stylesheet is gone and Collection keeps its page owner" do
    assert_not ROOT.join("legacy.css").exist?
    assert_empty DECLARATION_CONTRACTS.keys - authored_declarations_for(ROOT.join(OWNER)).keys
    assert_no_match(/\blegacy\b/, ROOT.join("application.css").read)
  end

  test "Collection owner does not absorb Monthly Migration" do
    owner = authored_declarations_for(ROOT.join(OWNER))

    assert_empty owner.keys.grep(/\A\.monthly-migration/)
    assert_not_includes owner, ".monthly-log__migration-link"
  end

  private

  def authored_rules
    ROOT.glob("**/*.css").each_with_object(Hash.new { |rules, selector| rules[selector] = [] }) do |path, rules|
      authored_declarations_for(path).each do |selector, declarations|
        rules[selector] << [ path.relative_path_from(ROOT).to_s, declarations ]
      end
    end
  end

  def authored_declarations_for(path)
    source = path.binread.gsub(%r{/\*.*?\*/}m, "")
    source.scan(/([^{}]+)\{([^{}]*)\}/m).each_with_object(Hash.new { |rules, selector| rules[selector] = [] }) do |(selector_list, body), rules|
      declarations = body.scan(/([-\w]+)\s*:\s*([^;]+);/).map do |property, value|
        [ property, value.strip ]
      end
      next if declarations.empty?

      selector_list.split(",").map(&:strip).each { |selector| rules[selector].concat(declarations) }
    end
  end
end
