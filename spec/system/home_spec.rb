# frozen_string_literal: true

require "rails_helper"

describe "Home page", type: :system do
  it "shows links to login and sign up when logged out" do
    visit root_path
    expect(page).to have_selector("h1", text: "Welcome")
    expect(page).to have_link("Login", href: login_path)
    expect(page).to have_link("Sign up", href: signup_path)
  end
end
