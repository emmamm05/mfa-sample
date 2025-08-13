# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Email registration", type: :system do
  it "allows a visitor to sign up successfully and becomes logged in" do
    visit signup_path

    fill_in "Email", with: "new.user@example.com"
    fill_in "Name", with: "New User"
    fill_in "Password", with: "password123"
    click_button "Create account"

    expect(page).to have_current_path(root_path, ignore_query: true)
    expect(page).to have_content("Welcome, you are signed up and logged in.")
    expect(page).to have_content("Signed in as new.user@example.com")
    expect(page).to have_button("Logout")
  end

  it "shows validation errors when trying to sign up with an existing email" do
    # Pre-create a user
    User.create!(email: "taken@example.com", name: "Taken", password: "password123")

    visit signup_path
    fill_in "Email", with: "taken@example.com"
    fill_in "Name", with: "Another User"
    fill_in "Password", with: "password123"
    click_button "Create account"

    expect(page).to have_current_path(signup_path, ignore_query: true)
    expect(page).to have_selector(".errors")
    expect(page).to have_content("error")
    expect(page).to have_content("Email has already been taken").or have_content("has already been taken")
  end
end
