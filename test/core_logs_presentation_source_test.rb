require "test_helper"

# Freezes the T3/6A declaration boundary for Daily, Monthly Tasks, and Future,
# plus the 6B Calendar body owner.
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
  CALENDAR_CONTRACTS = {
    ".monthly-calendar" => %w[padding],
    ".monthly-calendar__day" =>
      %w[display min-height grid-template-columns gap align-items padding border-radius color],
    ".monthly-calendar__capture-reveal" =>
      %w[display min-height grid-row grid-column grid-template-columns gap align-items padding border background color font text-align cursor],
    ".monthly-calendar__date" =>
      %w[display min-height grid-row grid-column grid-template-columns gap align-items padding border background color font text-align],
    ".monthly-calendar__residents" =>
      %w[z-index min-width grid-row grid-column pointer-events],
    ".monthly-calendar__residents .entry" => %w[padding pointer-events],
    ".monthly-calendar__daily-link" =>
      %w[z-index display min-width min-height grid-row grid-column place-items color font-size text-decoration],
    ".monthly-calendar__capture-panel" => %w[z-index grid-row grid-column padding],
    ".monthly-calendar__day--today" => %w[background],
    ".monthly-calendar__day--today .monthly-calendar__number" => %w[color],
    ".monthly-calendar__day--today .monthly-calendar__weekday" => %w[color],
    ".monthly-calendar__number" => %w[font-family text-align],
    ".monthly-calendar__weekday" => %w[font-family color]
  }.freeze

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

  test "Calendar declarations have one Monthly page owner" do
    rules = authored_rules

    CALENDAR_CONTRACTS.each do |selector, required_properties|
      matches = rules.fetch(selector, [])
      assert_equal [ "pages/monthly.css" ], matches.map(&:first).uniq,
        "#{selector} declarations must live only in pages/monthly.css"

      properties = matches.flat_map(&:last).uniq
      required_properties.each do |property|
        assert_includes properties, property, "#{selector} must own #{property}"
      end
    end
  end

  test "legacy stylesheet is gone and the T0-dead Calendar glyph has no owner" do
    monthly = ROOT.join("pages/monthly.css").read

    assert_not ROOT.join("legacy.css").exist?
    assert_no_match(/monthly-calendar__glyph--event/, monthly)
    assert_no_match(/TODO\(8\)/, monthly)
    assert_match(/\.monthly-calendar__day--today \.monthly-calendar__number,\s*\.monthly-calendar__day--today \.monthly-calendar__weekday\s*\{\s*color:\s*var\(--accent\);/m, monthly)
  end

  test "Calendar body declarations remain byte-for-value equivalent to T0" do
    monthly = authored_declarations_for(ROOT.join("pages/monthly.css"))
    baseline = authored_declarations_for(T0_STYLESHEET)

    CALENDAR_CONTRACTS.each_key do |selector|
      assert_equal baseline.fetch(selector), monthly.fetch(selector),
        "#{selector} must retain its T0 declarations under the Monthly page owner"
    end
  end

  test "core-log families do not leak selectors into one another" do
    daily = authored_rules_for(ROOT.join("pages/daily.css"))
    monthly = authored_rules_for(ROOT.join("pages/monthly.css"))
    future = authored_rules_for(ROOT.join("pages/future.css"))

    assert_empty daily.keys.grep(/\A\.future(?:-log|\-entry)/)
    assert_empty daily.keys.grep(/\A\.monthly-(?:task|tasks|calendar)/)
    assert_empty future.keys.grep(/\A\.daily-log/)
    assert_empty future.keys.grep(/\A\.monthly-(?:task|tasks|calendar)/)
    assert_empty monthly.keys.grep(/\A\.future(?:-log|\-entry)/)
    assert_empty monthly.keys.grep(/\A\.daily-log/)
  end

  test "Monthly page owner retains 6A declarations and does not absorb Migration declarations" do
    monthly = authored_rules_for(ROOT.join("pages/monthly.css"))

    assert_equal CALENDAR_CONTRACTS.keys.sort, monthly.keys.grep(/\A\.monthly-calendar/).sort
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
