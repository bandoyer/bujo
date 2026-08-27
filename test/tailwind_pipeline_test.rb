require "test_helper"
require "digest"
require "fileutils"
require "open3"

# Pins the generated stylesheet boundary while the byte-identical legacy rules
# remain the sole owner of presentation during the T1 checkpoint.
class TailwindPipelineTest < ActiveSupport::TestCase
  LEGACY_STYLESHEET = Rails.root.join("app/assets/tailwind/legacy.css")
  TAILWIND_ENTRY = Rails.root.join("app/assets/tailwind/application.css")
  TAILWIND_OUTPUT = Rails.root.join("app/assets/builds/tailwind.css")
  LEGACY_SHA256 = "df75385665a9f4f48af1f66156953e712493c2e85575de861ffc09963bfa5ceb"
  TEST_ONLY_UTILITY = "w-[123px]"
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
    pages/future.css
    pages/monthly.css
    pages/monthly-migration.css
  ].freeze

  test "legacy presentation source is preserved once and byte for byte" do
    assert_path_exists LEGACY_STYLESHEET
    assert_equal 23_218, LEGACY_STYLESHEET.size
    assert_equal LEGACY_SHA256, Digest::SHA256.file(LEGACY_STYLESHEET).hexdigest
    assert_not Rails.root.join("app/assets/stylesheets/application.css").exist?
  end

  test "entry disables framework defaults and scans only application sources" do
    entry = TAILWIND_ENTRY.read

    assert_match(/\A@layer theme, base, legacy, components, utilities;/, entry)
    assert_includes entry, '@import "tailwindcss/theme.css" layer(theme);'
    assert_includes entry, '@import "tailwindcss/utilities.css" layer(utilities) source(none);'
    assert_includes entry, '@import "./legacy.css" layer(legacy);'
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

  test "clean and repeated one-shot builds are byte stable" do
    with_build_lock do
      FileUtils.rm_f(TAILWIND_OUTPUT)

      first_output = build_tailwind
      assert first_output.success?, first_output.error
      first_hash = Digest::SHA256.file(TAILWIND_OUTPUT).hexdigest
      second_output = build_tailwind
      assert second_output.success?, second_output.error
      second_hash = Digest::SHA256.file(TAILWIND_OUTPUT).hexdigest
      generated_css = TAILWIND_OUTPUT.read

      assert_equal first_hash, second_hash
      assert_no_match(/--color-red-500|--font-sans|--spacing:/, generated_css)
      assert_no_match(/optgroup|::backdrop|w-\\\[123px\\\]/, generated_css)
    end
  end

  test "test preparation replaces a stale generated artifact" do
    with_build_lock do
      TAILWIND_OUTPUT.write("stale output")

      output = prepare_tests

      assert output.success?, output.error
      assert_not_equal "stale output", TAILWIND_OUTPUT.read
      assert_includes TAILWIND_OUTPUT.read, ".daily-log"
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

  def build_tailwind
    _output, error, status = Open3.capture3(
      { "RAILS_ENV" => "test" },
      Rails.root.join("bin/rails").to_s,
      "tailwindcss:build",
      chdir: Rails.root.to_s
    )
    BuildResult.new(status.success?, error)
  end

  def prepare_tests
    _output, error, status = Open3.capture3(
      { "RAILS_ENV" => "test" },
      Rails.root.join("bin/rails").to_s,
      "test:prepare",
      chdir: Rails.root.to_s
    )
    BuildResult.new(status.success?, error)
  end

  def with_build_lock
    Rails.root.join("tmp/tailwind-pipeline-test.lock").open(File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      yield
    end
  end
end
