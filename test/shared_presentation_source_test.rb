require "test_helper"

# Guards readable T2 ownership boundaries. Rendered system tests carry the
# geometry and behavior contract; this test prevents declarations drifting
# back into the later-page checkpoint.
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
    ".rapid-log__submit" => [ "components/rapid-log.css", %w[min-width min-height border background color] ]
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

  test "legacy retains only explicitly deferred T3 and T4 composition" do
    legacy = ROOT.join("legacy.css").read

    %w[:root body .visually-hidden .flash .preference-toggle__button .rapid-log .tab-bar].each do |selector|
      assert_no_match(/^#{Regexp.escape(selector)}(?:\s|,|\{|:)/, legacy, "#{selector} still owns a legacy rule")
    end
    assert_match(/TODO\(T3\):/, legacy)
    assert_match(/TODO\(T4\):/, legacy)
  end

  private

  def authored_rules
    ROOT.glob("**/*.css").each_with_object(Hash.new { |rules, selector| rules[selector] = [] }) do |path, rules|
      source = path.read.gsub(%r{/\*.*?\*/}m, "")
      source.scan(/([^{}]+)\{([^{}]*)\}/m) do |selector_list, body|
        properties = body.scan(/(?:\A|;)\s*([-\w]+)\s*:/).flatten
        next if properties.empty?

        selector_list.split(",").map(&:strip).each do |selector|
          rules[selector] << [ path.relative_path_from(ROOT).to_s, properties ]
        end
      end
    end
  end
end
