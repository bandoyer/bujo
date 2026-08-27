require "test_helper"

# Freezes the final T4 page-family boundary. Browser tests own rendered parity;
# this contract keeps every residual Monthly Migration declaration under its
# page owner and limits auth-specific CSS to the generator-era flash colors.
class MonthlyMigrationAuthPresentationSourceTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("app/assets/tailwind")
  MIGRATION_OWNER = "pages/monthly-migration.css"
  AUTH_OWNER = "pages/auth.css"
  T0_STYLESHEET = Rails.root.join("test/fixtures/files/tailwind_v4_t0.css")
  MIGRATION_DECLARATIONS = {
    ".monthly-migration .entry-list" => %w[padding],
    ".monthly-log__migration-link" => %w[padding border-radius grid-column justify-self],
    ".monthly-migration__primary-link" => %w[padding border-radius align-self margin-top],
    ".monthly-migration__completion-links a" => %w[padding border-radius flex],
    ".monthly-migration" => %w[gap],
    ".monthly-migration__context" => %w[margin overflow-wrap color font-family color],
    ".monthly-migration__stage" => %w[margin overflow-wrap color font-family padding-bottom border-bottom],
    ".monthly-migration__source" => %w[margin overflow-wrap color font-family margin-top font-size],
    ".monthly-migration__preferences" => %w[display flex-wrap gap margin-top],
    ".monthly-migration__inventory" => %w[min-width margin-top],
    ".monthly-migration__tree" => %w[min-width margin-top],
    ".monthly-migration__complete" => %w[min-width margin-top],
    ".monthly-migration__checkpoint" => %w[min-width margin-top],
    ".monthly-migration__confirmation" => %w[min-width margin-top min-height padding border-bottom],
    ".monthly-migration__confirmation p" => %w[margin],
    ".monthly-migration__confirmation form" => %w[margin],
    ".monthly-migration__checkpoint p" => %w[margin],
    ".monthly-migration__capture" => %w[min-width margin-top padding border border-radius background],
    ".monthly-migration__capture > label" => %w[display margin-bottom],
    ".monthly-migration__second-step label" => %w[display margin-bottom],
    ".monthly-migration__capture-row" => %w[gap],
    ".monthly-migration__choices" => %w[gap],
    ".monthly-migration__second-step" => %w[gap],
    ".monthly-migration__second-step form" => %w[gap flex],
    ".monthly-migration__completion-links" => %w[gap],
    ".monthly-migration__capture-row input" => %w[flex padding border-radius],
    ".monthly-migration__second-step input" => %w[flex padding border-radius],
    ".monthly-migration__candidate" => %w[min-width],
    ".monthly-migration__actions" => %w[min-width margin margin-left],
    ".monthly-migration__actions form" => %w[margin],
    ".monthly-migration__button" => %w[padding border-radius flex],
    ".monthly-migration__complete h2" => %w[margin overflow-wrap font-size]
  }.freeze
  AUTH_DECLARATIONS = {
    ".auth-flash--alert" => [ [ "color", "red" ] ],
    ".auth-flash--notice" => [ [ "color", "green" ] ]
  }.freeze
  T0_SHARED_SELECTORS = {
    ".monthly-migration .entry-list" => ".entry-list"
  }.freeze

  test "all 32 residual Migration selectors and 83 occurrences have one page owner" do
    assert_equal 32, MIGRATION_DECLARATIONS.size
    assert_equal 83, MIGRATION_DECLARATIONS.values.sum(&:size)

    rules = authored_rules
    MIGRATION_DECLARATIONS.each do |selector, properties|
      properties.uniq.each do |property|
        owners = rules.fetch(selector, []).filter_map do |owner, declarations|
          owner if declarations.assoc(property)
        end.uniq
        assert_equal [ MIGRATION_OWNER ], owners, "#{selector} #{property} must live only in #{MIGRATION_OWNER}"
      end
    end
  end

  test "Migration owner retains every residual T0 value and narrow-phone context" do
    owner = authored_declarations_for(ROOT.join(MIGRATION_OWNER))
    baseline = authored_declarations_for(T0_STYLESHEET)

    assert_equal MIGRATION_DECLARATIONS.keys.sort, owner.keys.sort
    assert_equal 83, owner.values.sum(&:size)
    MIGRATION_DECLARATIONS.each do |selector, properties|
      baseline_selector = T0_SHARED_SELECTORS.fetch(selector, selector)
      expected = declarations_matching(baseline.fetch(baseline_selector), properties)
      assert_equal expected, owner.fetch(selector), "#{selector} must retain its residual T0 declarations in source order"
    end

    source = ROOT.join(MIGRATION_OWNER).read
    phone_rule = source[/@media \(max-width: 340px\) \{(?<body>.*)\}\s*\z/m, :body]
    assert phone_rule, "Migration owner must retain its max-width: 340px context"
    assert_match(/\.monthly-migration__actions\s*\{\s*margin-left:\s*0;/m, phone_rule)
    assert_match(/\.monthly-migration__button,\s*\.monthly-migration__completion-links a\s*\{\s*flex:\s*1 1 8rem;/m,
      phone_rule)
  end

  test "legacy stylesheet is gone and Migration keeps its page owner" do
    assert_not ROOT.join("legacy.css").exist?
    assert_empty MIGRATION_DECLARATIONS.keys - authored_declarations_for(ROOT.join(MIGRATION_OWNER)).keys
    assert_no_match(/\blegacy\b/, ROOT.join("application.css").read)
  end

  test "Migration owner does not absorb an accepted page or shared family" do
    selectors = authored_declarations_for(ROOT.join(MIGRATION_OWNER)).keys

    assert_empty selectors.grep(/\A\.(?:collection|daily-log|entry(?:__|--|\z)|future|monthly-calendar|monthly-task)/)
    assert_empty selectors.grep(/\A\.(?:action|field|notice|page-shell|preference|rapid-log|tab-bar)/)
  end

  test "auth-specific flash colors have one page owner and no inline competitor" do
    rules = authored_rules
    owner = authored_declarations_for(ROOT.join(AUTH_OWNER))

    assert_equal AUTH_DECLARATIONS, owner
    AUTH_DECLARATIONS.each_key do |selector|
      assert_equal [ AUTH_OWNER ], rules.fetch(selector).map(&:first).uniq
    end

    auth_views.each do |path|
      source = path.read
      assert_no_match(/\bstyle\s*(?:=|:)/, source, "#{path.relative_path_from(Rails.root)} retains inline presentation")
    end
    assert_includes Rails.root.join("app/views/sessions/new.html.erb").read, "auth-flash--notice"
    assert_equal 3, auth_views.count { |path| path.read.include?("auth-flash--alert") }
    %w[sessions/new.html.erb passwords/new.html.erb].each do |relative_path|
      assert_includes Rails.root.join("app/views", relative_path).read, "value: params[:email_address]"
    end
  end

  private

  def auth_views
    %w[sessions/new.html.erb passwords/new.html.erb passwords/edit.html.erb].map do |relative_path|
      Rails.root.join("app/views", relative_path)
    end
  end

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

  def declarations_matching(declarations, properties)
    remaining = properties.dup
    declarations.filter_map do |declaration|
      index = remaining.index(declaration.first)
      next unless index

      remaining.delete_at(index)
      declaration
    end.tap { assert_empty remaining }
  end
end
