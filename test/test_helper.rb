ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Capybara + Cuprite setup for system tests
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  # Toggle headless mode via HEADLESS env var (default is headless for CI)
  # Examples:
  #   bin/rails test:system                 -> headless (default)
  #   HEADLESS=false bin/rails test:system  -> headful (visible)
  headless_env = ENV.fetch("HEADLESS", "").downcase
  headless = !(%w[0 false no].include?(headless_env))

  Capybara::Cuprite::Driver.new(app,
    headless: headless,
    window_size: [1400, 1400],
    js_errors: true,
    process_timeout: 15,
    timeout: 15,
    browser_options: {
      "no-sandbox": nil,
      "disable-dev-shm-usage": nil
    }
  )
end

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: true }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
