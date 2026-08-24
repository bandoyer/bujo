require "test_helper"
require "open3"

# The rapid-log grammar is the one piece of bujo every client shares — the
# Hotwire PWA now, the TUI later — so slice 1.1 specifies it as pure Ruby over
# stdlib Date: no Rails, no I/O, no clock, no environment. Packwerk is this
# project's boundary checker, but the app is still a single root package with
# no packwerk installed, so this is the require-graph test the toolset article
# calls for in its place.
#
# The load check has to leave this process to mean anything: test_helper boots
# Rails before any test runs, so ActiveSupport is already loaded by the time a
# test executes, and an accidental `2.days` or `text.presence` in the parser
# would sail through the entire suite.
#
# Deliberately no `cover` declaration. These tests read the parser from disk
# instead of exercising the loaded constant, so they can never kill a mutant
# and would only cost the mutation run time.
class RapidLogBoundaryTest < ActiveSupport::TestCase
  SOURCE_FILES = Rails.root.glob("lib/bujo/**/*.rb").freeze
  # The parser resolves relative dates against the today it is handed. Any of
  # these would mean it had reached for ambient state instead.
  AMBIENT_STATE_PATTERN = /Date\.today|Time\.|DateTime|ENV/
  ALLOWED_REQUIRES = %w[date].freeze

  setup do
    assert_not_empty SOURCE_FILES, "the boundary tests must actually read the parser sources"
  end

  test "the grammar parses in a process that has never loaded Rails" do
    standard_output, error_output, status = parse_without_rails

    assert_predicate status, :success?, error_output
    assert_equal "task 2026-08-25 18:00 work", standard_output
  end

  test "no source file reaches for the clock, the zone, or the environment" do
    assert_empty ambient_state_references,
      "lib/bujo must resolve dates from its today: argument alone"
  end

  test "the grammar requires nothing beyond stdlib date" do
    assert_empty external_requires - ALLOWED_REQUIRES,
      "the parser may only require stdlib date; require_relative stays free for internal decomposition"
  end

  private

  # Loads and exercises the parser in a bare Ruby process, outside bundler, so
  # that anything Rails-shaped in the require graph fails loudly.
  def parse_without_rails
    script = <<~RUBY
      $LOAD_PATH.unshift(#{Rails.root.join("lib").to_s.inspect})
      require "bujo/rapid_log"
      raise "Rails leaked into the parser" if defined?(Rails)
      raise "ActiveSupport leaked into the parser" if defined?(ActiveSupport)

      parsed = Bujo::RapidLog.parse("x ship it +work tomorrow 6pm", today: Date.new(2026, 8, 24))
      print [ parsed.kind, parsed.date, parsed.time, parsed.tags.first ].join(" ")
    RUBY

    Bundler.with_unbundled_env { Open3.capture3(RbConfig.ruby, "-e", script) }
  end

  def ambient_state_references
    SOURCE_FILES.flat_map do |path|
      matching_lines(path, AMBIENT_STATE_PATTERN)
    end
  end

  def matching_lines(path, pattern)
    path.readlines.each_with_index.filter_map do |line, index|
      "#{path.relative_path_from(Rails.root)}:#{index + 1}: #{line.strip}" if line.match?(pattern)
    end
  end

  # require_relative is intentionally excluded: internal decomposition under
  # lib/bujo/rapid_log/ is the coder's call, external dependencies are not.
  def external_requires
    SOURCE_FILES.flat_map { |path| path.read.scan(/^\s*require\s+["']([^"']+)["']/) }.flatten.uniq
  end
end
