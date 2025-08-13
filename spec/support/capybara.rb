# frozen_string_literal: true

# Capybara + Cuprite setup for system specs
Capybara.register_driver(:cuprite) do |app|
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
Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  # Use Cuprite for system specs by default
  config.before(type: :system) do
    driven_by :cuprite
  end
end
