# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Email sign in", type: :system do
  it "allows an existing user without 2FA to sign in successfully" do
    User.create!(email: "login.user@example.com", name: "Login User", password: "password123")

    visit login_path
    fill_in "Email", with: "login.user@example.com"
    fill_in "Password", with: "password123"
    click_button "Login"

    expect(page).to have_current_path(root_path, ignore_query: true)
    expect(page).to have_content("Signed in successfully.")
    expect(page).to have_content("Signed in as login.user@example.com")
    expect(page).to have_button("Logout")
  end

  it "shows an error when credentials are invalid" do
    User.create!(email: "wrong.pass@example.com", name: "Wrong Pass", password: "correctpass")

    visit login_path
    fill_in "Email", with: "wrong.pass@example.com"
    fill_in "Password", with: "incorrectpass"
    click_button "Login"

    expect(page).to have_current_path(login_path, ignore_query: true)
    expect(page).to have_content("Invalid email or password")
    expect(page).to have_selector("h1", text: "Login")
  end
end
