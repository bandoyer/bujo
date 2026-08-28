require "test_helper"
require "digest"
require "fileutils"
require "open3"

# Pins the generated stylesheet boundary after legacy removal: one compiled
# asset, explicit application sources, and no second CSS bundle.
class TailwindPipelineTest < ActiveSupport::TestCase
  LEGACY_STYLESHEET = Rails.root.join("app/assets/tailwind/legacy.css")
  TAILWIND_ENTRY = Rails.root.join("app/assets/tailwind/application.css")
  TAILWIND_OUTPUT = Rails.root.join("app/assets/builds/tailwind.css")
  TEST_ONLY_UTILITY = "w-[123px]"
  ISOLATED_APPLICATION_PATHS = %w[
    .ruby-version
    Gemfile
    Gemfile.lock
    Rakefile
    app
    bin
    config
    db
    lib
    vendor
  ].freeze
  SOURCE_MODULES = %w[
    tokens.css
    base.css
    components/actions.css
    components/entries.css
    components/fields.css
    components/notices.css
    components/page-shell.css
    components/preferences.css
    components/rapid-log.css
    components/tab-bar.css
    pages/auth.css
    pages/collections.css
    pages/daily.css
    pages/daily-reflection.css
    pages/future.css
    pages/monthly.css
    pages/monthly-migration.css
  ].freeze

  test "legacy source is gone and the T0-dead Calendar glyph is not delivered" do
    monthly = Rails.root.join("app/assets/tailwind/pages/monthly.css").read

    assert_not LEGACY_STYLESHEET.exist?
    assert_not Rails.root.join("app/assets/stylesheets/application.css").exist?
    assert_not Rails.root.join("app/assets/stylesheets/legacy.css").exist?
    assert_no_match(/TODO\(8\)/, monthly)
    assert_no_match(/\.monthly-calendar__glyph--event/, monthly)
    assert_match(/\.monthly-calendar__day--today \.monthly-calendar__number,\s*\.monthly-calendar__day--today \.monthly-calendar__weekday\s*\{\s*color:\s*var\(--accent\);/m, monthly)
  end

  test "entry disables framework defaults and scans only application sources" do
    entry = TAILWIND_ENTRY.read

    assert_match(/\A@layer theme, base, components, utilities;/, entry)
    assert_includes entry, '@import "tailwindcss/theme.css" layer(theme);'
    assert_includes entry, '@import "tailwindcss/utilities.css" layer(utilities) source(none);'
    assert_no_match(/\blegacy\b/, entry)
    assert_no_match(/preflight\.css|@import\s+["']tailwindcss["']/, entry)
    assert_equal %w[../../views ../../helpers ../../javascript], entry.scan(/@source\s+"([^"]+)"/).flatten

    tokens = Rails.root.join("app/assets/tailwind/tokens.css").read
    assert_match(/@theme\s*\{\s*--\*:\s*initial;\s*\}/m, tokens)
    SOURCE_MODULES.each { |source| assert_path_exists Rails.root.join("app/assets/tailwind", source) }
  end

  test "Ruby-hosted compiler versions and single-process development are pinned" do
    gemfile = Rails.root.join("Gemfile").read
    lockfile = Rails.root.join("Gemfile.lock").read
    puma = Rails.root.join("config/puma.rb").read

    assert_includes gemfile, 'gem "tailwindcss-rails", "4.6.0"'
    assert_includes gemfile, 'gem "tailwindcss-ruby", "4.3.3"'
    assert_match(/^    tailwindcss-rails \(4\.6\.0\)$/m, lockfile)
    assert_match(/^    tailwindcss-ruby \(4\.3\.3\)$/m, lockfile)
    assert_includes puma,
      'plugin :tailwindcss if ENV.fetch("RAILS_ENV", "development") == "development"'
    assert_equal %(#!/usr/bin/env ruby\nexec "./bin/rails", "server", *ARGV\n),
      Rails.root.join("bin/dev").read
    assert_not Rails.root.join("Procfile.dev").exist?
    assert_no_match(/foreman/i, gemfile)
    assert_empty Rails.root.glob("{package.json,package-lock.json,pnpm-lock.yaml,yarn.lock,bun.lock,bun.lockb,.nvmrc}")
  end

  test "clean test preparation creates a byte-stable generated artifact" do
    with_isolated_application do |root|
      output_path = root.join("app/assets/builds/tailwind.css")
      FileUtils.rm_f(output_path)

      first_output = prepare_tests(root: root)
      assert first_output.success?, first_output.error
      assert_path_exists output_path
      first_hash = Digest::SHA256.file(output_path).hexdigest
      second_output = prepare_tests(root: root)
      assert second_output.success?, second_output.error
      second_hash = Digest::SHA256.file(output_path).hexdigest
      generated_css = output_path.read

      assert_equal first_hash, second_hash
      assert_no_match(/--color-red-500|--font-sans|--spacing:/, generated_css)
      assert_no_match(/optgroup|::backdrop|w-\\\[123px\\\]/, generated_css)
    end
  end

  test "test preparation replaces a stale generated artifact" do
    with_isolated_application do |root|
      output_path = root.join("app/assets/builds/tailwind.css")
      output_path.write("stale output")

      output = prepare_tests(root: root)

      assert output.success?, output.error
      assert_not_equal "stale output", output_path.read
      assert_includes output_path.read, ".page-shell"
    end
  end

  test "conditional class literals survive a production-shaped extraction" do
    with_isolated_application do |root|
      output_path = root.join("app/assets/builds/tailwind.css")
      FileUtils.rm_f(output_path)
      output = prepare_tests(root: root)
      assert output.success?, output.error

      generated = output_path.read
      conditional_class_literals.each do |class_name|
        assert_match(/#{Regexp.escape(class_name)}/, generated,
          "#{class_name} missing from the isolated production-shaped bundle")
      end
      assert_no_match(/w-\\\[123px\\\]/, generated)
      assert_no_match(/monthly-calendar__glyph--event/, generated)
    end
  end

  test "Propshaft exposes one generated stylesheet and no raw source" do
    with_build_lock do
      load_path = Rails.application.assets.load_path

      assert load_path.find("tailwind.css")
      assert_nil load_path.find("application.css")
      assert_nil load_path.find("legacy.css")
      assert_includes Rails.application.config.assets.excluded_paths,
        Rails.root.join("app/assets/tailwind")
    end
  end

  test "test CI production and Docker paths build the same Tailwind source" do
    workflow = Rails.root.join(".github/workflows/ci.yml").read
    dockerfile = Rails.root.join("Dockerfile").read
    _output, task_trace, status = Open3.capture3(
      Rails.root.join("bin/rails").to_s,
      "test:prepare",
      "--dry-run",
      "--trace",
      chdir: Rails.root.to_s
    )

    assert status.success?, task_trace
    assert_match(/Invoke tailwindcss:build/, task_trace)
    assert_equal 2, workflow.scan(/^\s*- name: Build Tailwind CSS$/).size
    assert_match(/RAILS_ENV:\s*test.*?bin\/rails tailwindcss:build.*?bin\/rails db:test:prepare test/m, workflow)
    assert_match(/RAILS_ENV:\s*test.*?bin\/rails tailwindcss:build.*?bin\/rails db:test:prepare test:system/m, workflow)
    assert_match(/SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin\/rails tailwindcss:build/, workflow)
    assert_match(/SECRET_KEY_BASE_DUMMY=1 \.\/bin\/rails tailwindcss:build.*assets:precompile/m, dockerfile)
    assert_no_match(/\b(node|npm|pnpm|yarn|bun)\b/i, dockerfile)
  end

  private

  BuildResult = Data.define(:success?, :error)

  def with_isolated_application
    Dir.mktmpdir("bujo-tailwind-test-prepare") do |directory|
      root = Pathname(directory)
      ISOLATED_APPLICATION_PATHS.each do |relative_path|
        FileUtils.cp_r(Rails.root.join(relative_path), root.join(relative_path), preserve: true)
      end
      root.join("tmp").mkpath
      root.join("storage").mkpath
      yield root
    end
  end

  def prepare_tests(root: Rails.root)
    _output, error, status = Open3.capture3(
      { "RAILS_ENV" => "test" },
      root.join("bin/rails").to_s,
      "test:prepare",
      chdir: root.to_s
    )
    BuildResult.new(status.success?, error)
  end

  def conditional_class_literals
    literals = []
    %w[app/views app/helpers app/javascript].each do |relative|
      root = Rails.root.join(relative)
      next unless root.exist?

      root.glob("**/*.{erb,rb,js}").each do |path|
        source = path.read
        literals.concat source.scan(/class_names\("[^"]+",\s*"([^"]+)":/).flatten
        literals.concat source.scan(/classList\.(?:toggle|add|remove)\("([^"]+)"/).flatten
        literals.concat source.scan(/<%=\s*"([^"]+)"\s+if/).flatten
      end
    end
    literals.flat_map(&:split).grep(/\A[a-z][a-z0-9_-]*\z/).uniq.sort
  end

  def with_build_lock
    Rails.root.join("tmp/tailwind-pipeline-test.lock").open(File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      yield
    end
  end
end
