require "test_helper"

# Guards readable T2 ownership boundaries. Rendered system tests carry the
# geometry and behavior contract; this test prevents declarations drifting
# back into the declaration-empty cleanup checkpoint.
class SharedPresentationSourceTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("app/assets/tailwind")
  DECLARATION_CONTRACTS = {
    ".visually-hidden" => [ "base.css", %w[position width height overflow clip] ],
    "[hidden]" => [ "base.css", %w[display] ],
    ".page-shell" => [ "components/page-shell.css", %w[display width flex padding] ],
    ".page-shell__header" => [ "components/page-shell.css", %w[display grid-template-columns border-bottom] ],
    ".page-shell__title" => [ "components/page-shell.css", %w[margin overflow-wrap font-family font-size line-height] ],
    ".action" => [ "components/actions.css", %w[min-width min-height cursor] ],
    ".action--surface" => [ "components/actions.css", %w[border background color] ],
    ".action--link" => [ "components/actions.css", %w[display place-items text-decoration] ],
    ".action--muted" => [ "components/actions.css", %w[color] ],
    ".action--warn" => [ "components/actions.css", %w[color] ],
    ".action-row" => [ "components/actions.css", %w[display min-width flex-wrap align-items] ],
    ".field" => [ "components/fields.css", %w[min-width min-height border background color] ],
    ".field-label" => [ "components/fields.css", %w[color] ],
    ".field--muted" => [ "components/fields.css", %w[color] ],
    ".notice" => [ "components/notices.css", %w[width margin padding border border-radius background] ],
    ".notice--alert" => [ "components/notices.css", %w[color] ],
    ".form-errors" => [ "components/notices.css", %w[color margin] ],
    ".state-text" => [ "components/notices.css", %w[color] ],
    ".state-text--empty" => [ "components/notices.css", %w[margin text-align] ],
    ".state-text--handwritten" => [ "components/notices.css", %w[font-family font-style] ],
    ".preference-toggle__button" => [ "components/preferences.css", %w[padding border background color font-family font-size] ],
    ".tab-bar" => [ "components/tab-bar.css", %w[position bottom display height grid-template-columns] ],
    ".tab-bar__item" => [ "components/tab-bar.css", %w[display min-height color text-decoration] ],
    ".tab-bar__icon" => [ "components/tab-bar.css", %w[width height stroke] ],
    ".tab-bar__item--active" => [ "components/tab-bar.css", %w[color] ],
    ".rapid-log" => [ "components/rapid-log.css", %w[position bottom padding border background] ],
    ".rapid-log--embedded" => [ "components/rapid-log.css", %w[position] ],
    ".rapid-log__kinds" => [ "components/rapid-log.css", %w[display gap margin-bottom] ],
    ".rapid-log__kind" => [ "components/rapid-log.css", %w[display width height border color] ],
    ".rapid-log__kind--selected" => [ "components/rapid-log.css", %w[border-color color] ],
    ".rapid-log__input-wrap" => [ "components/rapid-log.css", %w[display overflow border background] ],
    ".rapid-log__capture-row:not(.rapid-log__capture-row--page-grid)" => [ "components/rapid-log.css", %w[display] ],
    ".rapid-log__capture-row" => [ "components/rapid-log.css", %w[min-width gap] ],
    ".rapid-log__submit" => [ "components/rapid-log.css", %w[min-width min-height border background color] ],
    ".entry:not(.monthly-calendar__residents .entry):not(.future-entry__resident .entry)" => [
      "components/entries.css", %w[padding]
    ],
    ".entry--selected" => [ "components/entries.css", %w[border-radius background] ],
    ".entry__line" => [ "components/entries.css", %w[display width min-height grid-template-columns gap align-items] ],
    ".entry__toggle" => [ "components/entries.css", %w[border-radius padding border background color cursor text-align] ],
    ".entry__signifier" => [ "components/entries.css", %w[color font-family] ],
    ".entry__glyph" => [ "components/entries.css", %w[color font-family] ],
    ".entry__text" => [ "components/entries.css", %w[min-width overflow-wrap] ],
    ".entry__text--struck" => [
      "components/entries.css", %w[text-decoration text-decoration-color text-decoration-thickness]
    ],
    ".entry__meta" => [
      "components/entries.css",
      %w[font-family min-width overflow-wrap display flex-wrap justify-content gap color font-size]
    ],
    ".entry__actions" => [ "components/entries.css", %w[gap] ],
    ".entry__action-strip" => [ "components/entries.css", %w[margin] ],
    ".entry__action-strip form" => [ "components/entries.css", %w[margin] ],
    ".entry-action" => [ "components/entries.css", %w[border-radius font-family font-size padding] ],
    ".entry-action--cancel" => [ "components/entries.css", %w[padding] ],
    ".entry__edit-step" => [ "components/entries.css", %w[gap align-items] ],
    ".entry__edit" => [ "components/entries.css", %w[min-width flex display] ],
    ".entry__edit .rapid-log__kinds" => [ "components/entries.css", %w[margin-bottom] ],
    ".entry__edit label" => [ "components/entries.css", %w[display margin-bottom font-family font-size] ],
    ".entry__edit-row" => [
      "components/entries.css", %w[display min-width grid-template-columns gap]
    ],
    ".entry__edit-row input[type=\"text\"]" => [ "components/entries.css", %w[padding border-radius] ],
    ".entry__schedule-step" => [ "components/entries.css", %w[gap align-items] ],
    ".entry__schedule" => [
      "components/entries.css", %w[min-width flex display grid-template-columns gap]
    ],
    ".entry__schedule label" => [ "components/entries.css", %w[font-family font-size] ],
    ".entry__schedule input[type=\"date\"]" => [
      "components/entries.css", %w[border-radius font-family font-size width padding]
    ],
    ".entry__schedule-actions" => [ "components/entries.css", %w[gap] ],
    ".entry__move-step" => [ "components/entries.css", %w[gap] ],
    ".entry__move" => [ "components/entries.css", %w[gap] ],
    ".entry__move input[type=\"text\"]" => [
      "components/entries.css", %w[border-radius font-family font-size max-width padding]
    ],
    ".entry__children" => [ "components/entries.css", %w[margin-left] ]
  }.freeze
  SHARED_VIEW_CLASS = /(?<![\w-])(?:page-shell(?:__[a-z][\w-]*)?|action(?:--[a-z][\w-]*)?|action-row|field(?:--[a-z][\w-]*)?|field-label|notice(?:--[a-z][\w-]*)?|state-text(?:--[a-z][\w-]*)?|rapid-log--[a-z][\w-]*|rapid-log__capture-row--[a-z][\w-]*)\b/

  test "each shared primitive has one declaration-level owner" do
    rules = authored_rules

    DECLARATION_CONTRACTS.each do |selector, (owner, required_properties)|
      matches = rules.fetch(selector, [])
      assert_equal [ owner ], matches.map(&:first).uniq, "#{selector} declarations must live only in #{owner}"

      owner_properties = matches.flat_map(&:last).uniq
      required_properties.each do |property|
        assert_includes owner_properties, property, "#{selector} must own #{property}"
      end
    end
  end

  test "shared view anatomy has a declared component owner" do
    rendered_literals = Rails.root.join("app/views").glob("**/*.erb").flat_map do |path|
      path.read.scan(/[\"']([^\"']+)[\"']/).flatten
    end.join(" ")
    adopted_classes = rendered_literals.scan(SHARED_VIEW_CLASS).uniq.sort
    declared_classes = DECLARATION_CONTRACTS.keys.flat_map { |selector| selector.scan(/\.([\w-]+)/).flatten }.uniq

    assert_empty adopted_classes - declared_classes,
      "shared view classes without a declaration owner: #{(adopted_classes - declared_classes).join(', ')}"
  end

  test "journal views adopt stable semantic primitive classes without replacing frozen hooks" do
    views = Rails.root.join("app/views")
    rendered_sources = views.glob("**/*.erb").map(&:read).join("\n")

    %w[page-shell page-shell__title action field field-label action-row notice state-text].each do |class_name|
      assert_match(/class(?:=|:).*\b#{Regexp.escape(class_name)}\b/, rendered_sources,
        "expected rendered use of .#{class_name}")
    end
    %w[entry entry__toggle entry__action-strip rapid-log__kind--selected future-log__month--empty].each do |hook|
      assert_includes rendered_sources, hook
    end
  end

  test "legacy retains no presentation declarations" do
    legacy = ROOT.join("legacy.css").read

    %w[:root body .visually-hidden .flash .preference-toggle__button .rapid-log .tab-bar].each do |selector|
      assert_no_match(/^#{Regexp.escape(selector)}(?:\s|,|\{|:)/, legacy, "#{selector} still owns a legacy rule")
    end
    assert_no_match(/TODO\(6B\):/, legacy)
    assert_no_match(/TODO\(7A\):/, legacy)
    assert_no_match(/TODO\(7B\):/, legacy)
    assert_empty authored_rules_for(ROOT.join("legacy.css"))
  end

  test "Entry declarations do not retain a competing legacy owner" do
    legacy_rules = authored_rules_for(ROOT.join("legacy.css"))
    entry_contracts = DECLARATION_CONTRACTS.keys.grep(/\A\.entry/)

    assert_empty entry_contracts & legacy_rules.keys,
      "Entry declarations must move completely out of legacy.css"
    assert_not_includes legacy_rules.keys, ".collection-page > .entry-list"
    assert_not_includes legacy_rules.keys, ".monthly-migration .entry-list"
    assert_not_includes legacy_rules.keys, ".monthly-calendar__residents .entry"
    assert_includes authored_rules_for(ROOT.join("pages/monthly.css")).keys,
      ".monthly-calendar__residents .entry"
    assert_not_includes legacy_rules.keys, ".future-entry__resident .entry"
  end

  test "Entry runtime hooks remain stable for Stimulus and rendered rows" do
    entry_views = %w[_entry.html.erb _task_actions.html.erb].map do |name|
      Rails.root.join("app/views/entries", name).read
    end.join("\n")
    controller = Rails.root.join("app/javascript/controllers/task_actions_controller.js").read

    %w[entry entry__toggle entry__action-strip].each do |hook|
      assert_includes entry_views, hook
      assert_includes controller, ".#{hook}"
    end
    assert_includes entry_views, "entry--selected"
    assert_includes controller, "entry--selected"
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
end
