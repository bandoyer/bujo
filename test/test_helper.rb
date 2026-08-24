if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-lcov"

  SimpleCov::Formatter::LcovFormatter.config.tap do |config|
    config.report_with_single_file = true
    config.single_report_path = File.join(SimpleCov.coverage_path, "lcov.info")
  end
  SimpleCov.formatter = SimpleCov::Formatter::LcovFormatter
  SimpleCov.start "rails"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mutant/minitest/coverage"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers. Coverage runs stay
    # single-process so SimpleCov sees every line in one report.
    parallelize(workers: ENV["COVERAGE"] ? 1 : :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Both models mint their own ids, so both suites make the same assertion.
    def assert_uuid_v7(id)
      assert_equal 36, id.length
      assert_equal "7", id[14]
    end
  end
end
