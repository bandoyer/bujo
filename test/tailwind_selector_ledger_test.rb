require "test_helper"
require "digest"
require "json"

# Final T5 owner ledger. Reconciles every immutable T0 selector row against
# current Tailwind sources without consulting Git history. Browser tests own
# rendered parity; this contract owns declaration/media ownership, the one
# proven-dead selector, runtime hooks, and frozen baseline receipts.
class TailwindSelectorLedgerTest < ActiveSupport::TestCase
  ROOT = Rails.root.join("app/assets/tailwind")
  T0_STYLESHEET = Rails.root.join("test/fixtures/files/tailwind_v4_t0.css")
  SELECTORS_CSV = Rails.root.join("docs/tailwind-v4-baseline/selectors.csv")
  DEAD_SELECTOR = ".monthly-calendar__glyph--event"
  T0_STYLESHEET_BYTES = 23_218
  T0_STYLESHEET_SHA256 = "df75385665a9f4f48af1f66156953e712493c2e85575de861ffc09963bfa5ceb"
  ARTIFACT_SHA256 = {
    "docs/tailwind-v4-baseline/geometry.json" =>
      "7058c8dbf766e420964c1aaa78a01d3ddbd6f3df91f1014070279e221c316b2c",
    "docs/tailwind-v4-baseline/selectors.csv" =>
      "1941f8bfd4dce0336658423b9d05368e2fd8265b0047339500606fa5c7ed7f64",
    "docs/tailwind-v4-baseline/screenshots.json" =>
      "24e90401941422a8e26674d4144f4fd1287b1755e265e43fb8472987c40d7713"
  }.freeze
  CATEGORY_COUNTS = {
    "token-base" => 15,
    "reusable-component" => 61,
    "page-specific-layout" => 122,
    "behavior-test-hook" => 23,
    "dead-or-superseded" => 1
  }.freeze
  CURRENT_FORMS = {
    ".daily-log" => [ ".page-shell" ],
    ".daily-log__header" => [ ".page-shell__header" ],
    ".daily-log h1" => [ ".page-shell__title" ],
    ".flash" => [ ".notice" ],
    ".flash--alert" => [ ".notice--alert" ],
    ".entry" => [ ".entry:not(.monthly-calendar__residents .entry):not(.future-entry__resident .entry)" ],
    ".entry-list" => [
      ".daily-log:not(.monthly-log):not(.collection-page) > .entry-list",
      ".monthly-tasks > .entry-list",
      ".collection-page > .entry-list",
      ".monthly-migration .entry-list"
    ],
    ".daily-log__capture" => [
      ".daily-log:not(.monthly-log):not(.collection-page) > .daily-log__capture",
      ".monthly-tasks > .daily-log__capture",
      ".collection-page > .daily-log__capture"
    ],
    ".daily-log__capture-reveal" => [
      ".daily-log:not(.monthly-log):not(.collection-page) > .daily-log__capture .daily-log__capture-reveal",
      ".monthly-tasks > .daily-log__capture .daily-log__capture-reveal",
      ".collection-page > .daily-log__capture .daily-log__capture-reveal"
    ],
    ".daily-log__capture-reveal .entry-list__empty" => [
      ".daily-log:not(.monthly-log):not(.collection-page) .daily-log__capture-reveal .entry-list__empty",
      ".collection-page > .daily-log__capture .daily-log__capture-reveal .entry-list__empty"
    ],
    ".rapid-log__capture-row" => [
      ".rapid-log__capture-row",
      ".rapid-log__capture-row:not(.rapid-log__capture-row--page-grid)"
    ]
  }.freeze
  SPECIALIZATIONS = [
    ".entry-list",
    ".daily-log__capture",
    ".daily-log__capture-reveal",
    ".daily-log__capture-reveal .entry-list__empty"
  ].freeze
  COMPOSED_WITH = {
    ".collection-page__button" => [ ".action", ".action--surface" ],
    ".collection-page__back" => [ ".action", ".action--surface", ".action--link" ],
    ".collection-page__button--warn" => [ ".action--warn" ],
    ".collection-index__topic-link" => [ ".action" ],
    ".entry-action" => [ ".action", ".action--surface", ".action--muted" ],
    ".entry-action--warn" => [ ".action--warn" ],
    ".monthly-migration__button" => [ ".action", ".action--surface" ],
    ".monthly-migration__button--warn" => [ ".action--warn" ],
    ".monthly-log__migration-link" => [ ".action", ".action--surface", ".action--link" ],
    ".monthly-migration__primary-link" => [ ".action", ".action--surface", ".action--link" ],
    ".monthly-migration__completion-links a" => [ ".action", ".action--surface", ".action--link" ],
    ".preference-toggle__button" => [ ".action" ],
    ".collection-form input[type=\"text\"]" => [ ".field" ],
    ".collection-form label" => [ ".field-label" ],
    ".entry__schedule input[type=\"date\"]" => [ ".field", ".field--muted" ],
    ".entry__move input[type=\"text\"]" => [ ".field", ".field--muted" ],
    ".entry__edit-row input[type=\"text\"]" => [ ".field" ],
    ".entry__schedule label" => [ ".field-label" ],
    ".entry__edit label" => [ ".field-label" ],
    ".future-log__add-row input[type=\"number\"]" => [ ".field" ],
    ".entry__actions" => [ ".action-row" ],
    ".entry__edit-step" => [ ".action-row" ],
    ".entry__schedule-step" => [ ".action-row" ],
    ".entry__schedule-actions" => [ ".action-row" ],
    ".entry__move-step" => [ ".action-row" ],
    ".entry__move" => [ ".action-row" ],
    ".monthly-migration__capture-row input" => [ ".field" ],
    ".monthly-migration__second-step input" => [ ".field" ],
    ".monthly-migration__capture > label" => [ ".field-label" ],
    ".monthly-migration__second-step label" => [ ".field-label" ],
    ".monthly-migration__capture-row" => [ ".action-row" ],
    ".monthly-migration__choices" => [ ".action-row" ],
    ".monthly-migration__second-step" => [ ".action-row" ],
    ".monthly-migration__second-step form" => [ ".action-row" ],
    ".monthly-migration__completion-links" => [ ".action-row" ],
    ".entry-list__empty" => [ ".state-text", ".state-text--empty", ".state-text--handwritten" ],
    ".collection-index__empty" => [ ".state-text", ".state-text--empty" ],
    ".daily-log__capture-reveal .entry-list__empty" => [ ".state-text" ]
  }.freeze
  RUNTIME_HOOKS = %w[
    entry
    entry__toggle
    entry__action-strip
    entry--selected
    future-log__month--empty
    rapid-log__kind--selected
    daily-log
    daily-log__header
    flash
    flash--alert
    collection-page__button--warn
    entry-action--warn
    monthly-migration__button--warn
    entry-list__empty
    collection-index__empty
  ].freeze
  STIMULUS_HOOKS = %w[entry entry__toggle entry__action-strip entry--selected rapid-log__kind--selected].freeze
  Rule = Data.define(:selector, :media, :declarations, :line, :owner)

  test "the immutable T0 ledger has 222 rows and frozen receipt hashes" do
    rows = ledger_rows
    assert_equal 222, rows.size
    assert_equal CATEGORY_COUNTS, rows.map { |row| row.fetch("category") }.tally
    assert_equal T0_STYLESHEET_BYTES, T0_STYLESHEET.binread.bytesize
    assert_equal T0_STYLESHEET_SHA256, Digest::SHA256.file(T0_STYLESHEET).hexdigest

    ARTIFACT_SHA256.each do |relative, digest|
      path = Rails.root.join(relative)
      assert_equal digest, Digest::SHA256.file(path).hexdigest, relative
    end
  end

  test "all 135 immutable screenshot receipts still match size and SHA-256" do
    manifest = JSON.parse(Rails.root.join("docs/tailwind-v4-baseline/screenshots.json").read)
    assert_equal 135, manifest.size

    manifest.each do |row|
      path = Rails.root.join("docs/tailwind-v4-baseline", row.fetch("path"))
      bytes = path.binread
      assert_equal row.fetch("bytes"), bytes.bytesize, row.fetch("path")
      assert_equal row.fetch("sha256"), Digest::SHA256.hexdigest(bytes), row.fetch("path")
    end
  end

  test "legacy source and cascade slot are absent from the final tree" do
    entry = ROOT.join("application.css").read

    assert_not ROOT.join("legacy.css").exist?
    assert_not Rails.root.join("app/assets/stylesheets/application.css").exist?
    assert_not Rails.root.join("app/assets/stylesheets/legacy.css").exist?
    assert_match(/\A@layer theme, base, components, utilities;/, entry)
    assert_no_match(/\blegacy\b/, entry)
    assert_no_match(/legacy\.css/, entry)
  end

  test "every live T0 declaration has exactly one coherent final owner" do
    rows = ledger_rows
    t0_rules = parse_css(T0_STYLESHEET.read, owner: "t0")
    current_rules = current_source_rules
    dead_rows, live_rows = rows.partition { |row| row.fetch("selector") == DEAD_SELECTOR }

    assert_equal 1, dead_rows.size
    assert_equal "dead-or-superseded", dead_rows.first.fetch("category")

    missing = []
    live_rows.each do |row|
      selector = row.fetch("selector")
      source_line = Integer(row.fetch("source_line"))
      t0_rule = t0_rules.find { |rule| rule.line == source_line && rule.selector == selector }
      assert t0_rule, "T0 rule missing for #{selector} at line #{source_line}"

      t0_rule.declarations.each do |property, value|
        next if native_element_effect?(selector, property, value)

        matches = matching_current_rules(current_rules, selector, property, value, t0_rule.media)
        if matches.empty?
          missing << "#{selector} #{property}: #{value} (#{t0_rule.media || "all"})"
          next
        end

        next unless SPECIALIZATIONS.include?(selector)

        composed = COMPOSED_WITH.fetch(selector, [])
        CURRENT_FORMS.fetch(selector).each do |form|
          next if matches.any? { |rule| rule.selector == form }
          next if matches.any? { |rule| composed.include?(rule.selector) }

          missing << "#{selector} #{property} missing specialized owner #{form}"
        end
      end
    end
    assert_empty missing, "unowned T0 obligations:\n#{missing.join("\n")}"
  end

  test "current sources do not silently duplicate a selector property media obligation" do
    grouped = current_source_rules.each_with_object(Hash.new { |h, k| h[k] = [] }) do |rule, index|
      rule.declarations.each do |property, value|
        index[[ rule.selector, rule.media, property ]] << [ rule.owner, value ]
      end
    end

    grouped.each do |(selector, media, property), owners|
      files = owners.map(&:first).uniq
      assert_equal 1, files.size,
        "#{selector} #{property} in #{media || "all"} is duplicated across #{files.join(", ")}"
    end
  end

  test "the sole T0-dead selector has no CSS view helper JS or test-driver owner" do
    monthly = ROOT.join("pages/monthly.css").read
    today_rule = monthly[/\.monthly-calendar__day--today \.monthly-calendar__number,\s*\.monthly-calendar__day--today \.monthly-calendar__weekday\s*\{([^}]+)\}/m, 1]

    assert_no_match(/monthly-calendar__glyph--event/, monthly)
    assert today_rule, "today number/weekday must keep a grouped accent rule"
    assert_match(/color:\s*var\(--accent\);/, today_rule)
    assert_empty current_source_rules.select { |rule| rule.selector == DEAD_SELECTOR }

    runtime_hits = application_runtime_paths.filter_map do |path|
      path.read.match?(DEAD_SELECTOR) ? path.relative_path_from(Rails.root).to_s : nil
    end
    assert_empty runtime_hits, "dead selector still has a runtime owner: #{runtime_hits.join(", ")}"
  end

  test "runtime and Stimulus semantic hooks remain in application sources" do
    rendered = application_source_for(%w[app/views app/javascript])

    RUNTIME_HOOKS.each do |hook|
      assert_match(/\b#{Regexp.escape(hook)}\b/, rendered, "missing runtime hook #{hook}")
    end

    controller = Rails.root.join("app/javascript/controllers/task_actions_controller.js").read
    rapid = Rails.root.join("app/javascript/controllers/rapid_log_controller.js").read
    STIMULUS_HOOKS.each do |hook|
      haystack = hook.start_with?("rapid-log") ? rapid : controller
      assert_match(/#{Regexp.escape(hook)}/, haystack, "missing Stimulus hook #{hook}")
    end
    assert_includes Rails.root.join("app/javascript/controllers/placement_controller.js").read,
      "future-log__month--empty"
  end

  private

  def ledger_rows
    lines = SELECTORS_CSV.readlines(chomp: true)
    header = parse_csv_line(lines.fetch(0))
    lines.drop(1).map { |line| header.zip(parse_csv_line(line)).to_h }
  end

  def parse_csv_line(line)
    fields = []
    current = +""
    quoted = false
    index = 0
    while index < line.length
      char = line[index]
      if quoted
        if char == '"' && line[index + 1] == '"'
          current << '"'
          index += 1
        elsif char == '"'
          quoted = false
        else
          current << char
        end
      elsif char == '"'
        quoted = true
      elsif char == ","
        fields << current
        current = +""
      else
        current << char
      end
      index += 1
    end
    fields << current
    fields
  end

  def current_source_rules
    ROOT.glob("**/*.css").reject { |path| path.basename.to_s == "application.css" }.flat_map do |path|
      parse_css(path.read, owner: path.relative_path_from(ROOT).to_s)
    end
  end

  def matching_current_rules(current_rules, t0_selector, property, value, media)
    candidates = candidate_selectors(t0_selector)
    current_rules.select do |rule|
      next unless candidates.include?(rule.selector)
      next unless media_compatible?(rule.media, media)
      pair = rule.declarations.assoc(property)
      next unless pair

      values_equivalent?(property, value, pair.last, current_rules)
    end
  end

  def candidate_selectors(t0_selector)
    forms = CURRENT_FORMS.fetch(t0_selector, [ t0_selector ])
    forms += COMPOSED_WITH.fetch(t0_selector, [])
    forms << "[hidden]" if t0_selector.end_with?("[hidden]")
    if t0_selector.end_with?(":focus-visible")
      forms << ":where(a, button, input):focus-visible"
      forms << t0_selector.delete_suffix(":focus-visible")
    end
    forms.uniq
  end

  def media_compatible?(current_media, t0_media)
    current_media == t0_media
  end

  def native_element_effect?(selector, property, value)
    return true if property == "text-decoration" && value == "none" && selector == ".collection-page__button"
    return true if selector == ".tab-bar" && property == "justify-content" && value == "center"

    false
  end

  def values_equivalent?(property, t0_value, current_value, source_rules)
    return true if current_value == t0_value
    return true if current_value.delete_suffix(" !important") == t0_value
    return true if property == "padding" &&
      t0_value == "1.5rem 1rem 4.25rem" &&
      current_value.include?("4.25rem") &&
      current_value.include?("safe-area-inset-bottom")
    return true if property == "grid-template-columns" &&
      t0_value == "1fr auto" &&
      current_value == "minmax(0, 1fr) auto"
    return true if property == "bottom" &&
      t0_value == "0" &&
      current_value.include?("safe-area-inset-bottom")
    return true if property == "grid-template-columns" &&
      t0_value == "repeat(4, minmax(0, 7rem))" &&
      current_value == "repeat(4, minmax(0, 1fr))"

    if (variable = current_value[/\Avar\((--[\w-]+)\)\z/, 1])
      defined = source_rules
        .select { |rule| rule.selector == ":root" && rule.media.nil? }
        .flat_map(&:declarations)
        .assoc(variable)
      return true if defined&.last == t0_value
    end

    false
  end

  def parse_css(source, owner:)
    text = source.gsub(%r{/\*.*?\*/}m) { |comment| comment.gsub(/[^\n]/, " ") }
    rules = []
    scan_rules(text, 0, text.length, nil, owner, rules)
    rules
  end

  def scan_rules(text, from, to, media, owner, rules)
    pos = from
    while (open = index_of(text, "{", pos, to))
      close = matching_brace(text, open)
      break if close.nil? || close >= to

      prelude = text[pos...open].strip
      line = text[0...leading_index(text, pos, open)].count("\n") + 1
      if prelude.start_with?("@media")
        nested = prelude.sub(/\A@media\s*/, "").gsub(/\s+/, " ").strip
        scan_rules(text, open + 1, close, nested, owner, rules)
      elsif !prelude.start_with?("@")
        declarations = text[(open + 1)...close].scan(/([-\w]+)\s*:\s*([^;]+);/).map do |property, value|
          [ property, value.strip ]
        end
        unless declarations.empty?
          split_selectors(prelude).each do |selector|
            rules << Rule.new(selector, media, declarations, line, owner)
          end
        end
      end
      pos = close + 1
    end
  end

  def leading_index(text, from, open)
    skip = text[from...open][/\A\s*/].to_s.length
    from + skip
  end

  def index_of(text, needle, from, to)
    index = text.index(needle, from)
    index if index && index < to
  end

  def matching_brace(text, open)
    depth = 1
    index = open + 1
    while index < text.length && depth.positive?
      char = text[index]
      depth += 1 if char == "{"
      depth -= 1 if char == "}"
      return index if depth.zero?

      index += 1
    end
    nil
  end

  def split_selectors(list)
    selectors = []
    buffer = +""
    depth = 0
    list.each_char do |char|
      case char
      when "(", "[" then depth += 1
      when ")", "]" then depth -= 1
      when ","
        if depth.zero?
          selectors << buffer.strip
          buffer = +""
          next
        end
      end
      buffer << char
    end
    selectors << buffer.strip unless buffer.strip.empty?
    selectors
  end

  def application_runtime_paths
    %w[app/views app/helpers app/javascript app/controllers test/system test/test_helpers].flat_map do |relative|
      root = Rails.root.join(relative)
      next [] unless root.exist?

      root.glob("**/*").select(&:file?)
    end
  end

  def application_source_for(relative_roots)
    relative_roots.flat_map { |relative| Rails.root.join(relative).glob("**/*.{erb,js,rb}") }
      .map(&:read).join("\n")
  end
end
