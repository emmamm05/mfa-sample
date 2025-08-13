require "application_system_test_case"

class HomeTest < ApplicationSystemTestCase
  test "visiting the home page shows links to login and sign up when logged out" do
    visit root_path
    assert_selector "h1", text: "Welcome"
    assert_link "Login", href: login_path
    assert_link "Sign up", href: signup_path
  end
end
