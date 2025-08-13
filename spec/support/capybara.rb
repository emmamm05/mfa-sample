# frozen_string_literal: true

# Capybara + Cuprite setup for system specs
Capybara.register_driver(:cuprite_external) do |app|
  options = {
    window_size: [1400, 1400],
    js_errors: true,
    process_timeout: 15,
    timeout: 15,
    browser_options: {
      "no-sandbox": nil,
      "disable-dev-shm-usage": nil
    }
  }
  options[:slowmo] = ENV["SLOWMO"].to_f if ENV["SLOWMO"]
  options[:browser_path] = ENV["CHROME_PATH"] if ENV["CHROME_PATH"]
  options[:headless] = false if ENV["HEADLESS"] == "false"
  options[:inspector] = true if ENV["INSPECTOR"] == "true"

  Capybara::Cuprite::Driver.new(app, options)
end

Capybara.default_max_wait_time = 5
Capybara.server = :puma, { Silent: false }
Capybara.javascript_driver = :cuprite_external

RSpec.configure do |config|
  # Use Cuprite for system specs by default
  config.before(type: :system) do
    driven_by :cuprite_external
  end
end
