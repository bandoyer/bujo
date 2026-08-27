require "test_helper"

# Freezes the T3/6A declaration boundary for Daily, Monthly Tasks, and Future.
# Browser tests own rendered parity; this source contract prevents later page
# checkpoints from inheriting these layouts or losing their retained rules.
class CoreLogsPresentationSourceTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("app/assets/tailwind")
  T0_STYLESHEET = Rails.root.join("test/fixtures/files/tailwind_v4_t0.css")
  PAGE_CONTRACTS = {
    "pages/daily.css" => {
      ".daily-log__utilities" => %w[display flex-direction align-items gap],
      ".daily-log__preferences" => %w[display flex-wrap justify-content],
      ".daily-log__open-count" => %w[font-family color font-size],
      ".day-navigation" => %w[font-family display grid-column justify-content align-items],
      ".day-navigation a" => %w[display min-width min-height place-items color text-decoration],
      ".day-navigation__viewed-day" => %w[color font-size],
      ".daily-log:not(.monthly-log):not(.collection-page) > .entry-list" => %w[padding],
      ".daily-log:not(.monthly-log):not(.collection-page) > .daily-log__capture" =>
        %w[display min-height flex flex-direction],
      ".daily-log:not(.monthly-log):not(.collection-page) > .daily-log__capture .daily-log__capture-reveal" =>
        %w[min-height padding border background cursor flex],
      ".daily-log__capture-cue" => %w[margin color font-family font-size],
      ".daily-log:not(.monthly-log):not(.collection-page) .daily-log__capture-reveal .entry-list__empty" =>
        %w[display]
    },
    "pages/monthly.css" => {
      ".monthly-log__views" => %w[display align-self padding border border-radius background],
      ".monthly-log__view-link" =>
        %w[display min-height padding place-items border-radius color font-family font-size text-decoration],
      ".monthly-log__view-link[aria-current=\"page\"]" => %w[background box-shadow color],
      ".monthly-task" => %w[display color text-decoration],
      ".monthly-task-count" => %w[font-family margin color font-size text-align],
      ".monthly-tasks" => %w[display min-height flex flex-direction],
      ".monthly-tasks > .entry-list" => %w[padding],
      ".monthly-tasks > .daily-log__capture" => %w[display min-height flex flex-direction],
      ".monthly-tasks > .daily-log__capture .daily-log__capture-reveal" =>
        %w[min-height padding border background cursor flex]
    },
    "pages/future.css" => {
      ".future-log__runway" => %w[padding],
      ".future-log__month" => %w[padding],
      ".future-log__month h2" => %w[font-family margin font-size font-weight letter-spacing],
      ".future-log__month h2 button" =>
        %w[display min-height align-items padding border background color cursor letter-spacing],
      ".future-log__month h2 span" => %w[display min-height align-items],
      ".future-log__month--empty h2 button" => %w[color],
      ".future-log__trailing-reveal" =>
        %w[display width min-height padding border background cursor],
      ".future-log__add-row .rapid-log" => %w[position margin-bottom],
      ".future-log__add-row .rapid-log__capture-row" => %w[display grid-template-columns],
      ".future-log__add-row input[type=\"number\"]" =>
        %w[width padding border-radius font-family text-align],
      ".future-entry" =>
        %w[display min-height grid-template-columns gap align-items color text-decoration],
      ".future-entry__resident" => %w[min-width],
      ".future-entry__resident .entry" => %w[min-width padding],
      ".future-entry__day" => %w[font-family color text-align]
    }
  }.freeze
  CALENDAR_SELECTORS = %w[
    .monthly-calendar
    .monthly-calendar__day
    .monthly-calendar__capture-reveal
    .monthly-calendar__date
    .monthly-calendar__residents
    .monthly-calendar__residents\ .entry
    .monthly-calendar__daily-link
    .monthly-calendar__capture-panel
    .monthly-calendar__day--today
    .monthly-calendar__day--today\ .monthly-calendar__number
    .monthly-calendar__day--today\ .monthly-calendar__weekday
    .monthly-calendar__glyph--event
    .monthly-calendar__number
    .monthly-calendar__weekday
  ].freeze

  test "Daily Monthly Tasks and Future declarations have one page owner" do
    rules = authored_rules

    PAGE_CONTRACTS.each do |owner, contracts|
      contracts.each do |selector, required_properties|
        matches = rules.fetch(selector, [])
        assert_equal [ owner ], matches.map(&:first).uniq,
          "#{selector} declarations must live only in #{owner}"

        properties = matches.flat_map(&:last).uniq
        required_properties.each do |property|
          assert_includes properties, property, "#{selector} must own #{property}"
        end
      end
    end
  end

  test "legacy retains exact Calendar Collection and Migration checkpoint owners" do
    legacy = authored_rules_for(ROOT.join("legacy.css"))

    CALENDAR_SELECTORS.each { |selector| assert_includes legacy, selector }
    assert_includes legacy, ".collection-index__create-reveal"
    assert_includes legacy, ".collection-page > .entry-list"
    assert_includes legacy, ".collection-page > .daily-log__capture"
    assert_includes legacy, ".collection-page > .daily-log__capture .daily-log__capture-reveal"
    assert_includes legacy, ".monthly-migration .entry-list"
    assert_includes legacy, ".monthly-log__migration-link"

    source = ROOT.join("legacy.css").read
    assert_includes source, "TODO(6B)"
    assert_includes source, "TODO(7A)"
    assert_includes source, "TODO(7B)"
  end

  test "Calendar body declarations remain byte-for-value equivalent to T0" do
    legacy = authored_declarations_for(ROOT.join("legacy.css"))
    baseline = authored_declarations_for(T0_STYLESHEET)

    CALENDAR_SELECTORS.each do |selector|
      assert_equal baseline.fetch(selector), legacy.fetch(selector),
        "#{selector} must remain unchanged for 6B"
    end
  end

  test "legacy has no competing core-log page declarations" do
    legacy = authored_rules_for(ROOT.join("legacy.css"))
    moved_selectors = PAGE_CONTRACTS.values.flat_map(&:keys)

    assert_empty moved_selectors & legacy.keys
    assert_empty legacy.keys.grep(/\A\.future(?:-log|\-entry)/)
    assert_empty legacy.keys.grep(/\A\.monthly-(?:task|tasks)/)
  end

  test "Monthly page owner does not absorb Calendar body or Migration declarations" do
    monthly = authored_rules_for(ROOT.join("pages/monthly.css"))

    assert_empty monthly.keys.grep(/\A\.monthly-calendar/)
    assert_empty monthly.keys.grep(/\A\.monthly-migration/)
    assert_not_includes monthly, ".monthly-log__migration-link"
  end

  private

  def authored_rules
    ROOT.glob("**/*.css").each_with_object(Hash.new { |rules, selector| rules[selector] = [] }) do |path, rules|
      authored_rules_for(path).each do |selector, properties|
        rules[selector] << [ path.relative_path_from(ROOT).to_s, properties ]
      end
    end
  end

  def authored_rules_for(path)
    source = path.read.gsub(%r{/\*.*?\*/}m, "")
    source.scan(/([^{}]+)\{([^{}]*)\}/m).each_with_object(Hash.new { |rules, selector| rules[selector] = [] }) do |(selector_list, body), rules|
      properties = body.scan(/(?:\A|;)\s*([-\w]+)\s*:/).flatten
      next if properties.empty?

      selector_list.split(",").map(&:strip).each { |selector| rules[selector].concat(properties) }
    end
  end

  def authored_declarations_for(path)
    source = path.read.gsub(%r{/\*.*?\*/}m, "")
    source.scan(/([^{}]+)\{([^{}]*)\}/m).each_with_object(Hash.new { |rules, selector| rules[selector] = [] }) do |(selector_list, body), rules|
      declarations = body.scan(/(?:\A|;)\s*([-\w]+)\s*:\s*([^;]+);/).map do |property, value|
        [ property, value.strip ]
      end
      next if declarations.empty?

      selector_list.split(",").map(&:strip).each { |selector| rules[selector].concat(declarations) }
    end
  end
end
