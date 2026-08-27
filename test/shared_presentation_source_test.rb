require "test_helper"

# Guards readable T2 ownership boundaries. Rendered system tests carry the
# geometry and behavior contract; this test prevents declarations drifting
# back into the later-page checkpoint.
class SharedPresentationSourceTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("app/assets/tailwind")
  OWNERS = {
    "base.css" => [ ":root", "body", ".visually-hidden", "[hidden]", ":focus-visible" ],
    "components/page-shell.css" => [ ".page-shell", ".page-shell__header", ".page-shell__title" ],
    "components/actions.css" => [ ".action", ".action--surface", ".action-row" ],
    "components/fields.css" => [ ".field", ".field-label" ],
    "components/notices.css" => [ ".notice", ".notice--alert", ".state-text" ],
    "components/preferences.css" => [ ".preference-toggle__button" ],
    "components/tab-bar.css" => [ ".tab-bar", ".tab-bar__item", ".tab-bar__item--active" ],
    "components/rapid-log.css" => [ ".rapid-log", ".rapid-log__kind", ".rapid-log__kind--selected" ]
  }.freeze

  test "each shared primitive has one named readable owner" do
    sources = OWNERS.transform_values { |selectors| selectors.index_with { |_selector| nil } }

    sources.each do |relative_path, selectors|
      source = ROOT.join(relative_path).read
      selectors.each_key { |selector| assert_includes source, selector, "#{selector} must live in #{relative_path}" }
    end

    shared_source = OWNERS.keys.map { |path| ROOT.join(path).read }.join("\n")
    OWNERS.values.flatten.each do |selector|
      owned_rules = shared_source.scan(/#{Regexp.escape(selector)}(?=\s|,|\{|:focus)/).size
      assert_equal 1, owned_rules, "#{selector} must have one T2 owner"
    end
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
end
