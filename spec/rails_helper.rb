# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "capybara/rspec"
require "capybara/cuprite"

# Prevent database truncation if the environment is production
ActiveRecord::Migration.maintain_test_schema!

# Load support files
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

RSpec.configure do |config|
  # If you are not using ActiveRecord, you can remove this line.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end
