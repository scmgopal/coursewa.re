require 'spec_helper'

describe 'Users' do

  it 'should handle signups' do
    visit signup_path

    email = Faker::Internet.email
    passwd = Faker::Product.letters(8)
    emails_count = ActionMailer::Base.deliveries.count

    within('#new_user') do
      fill_in 'user_email', :with => email
      fill_in 'user_password', :with => passwd
      fill_in 'user_password_confirmation', :with => passwd
    end

    click_button 'submit_signup'

    page.should have_css('#notifications .alert-box')

    user = Coursewareable::User.find_by_email(email)
    user.should_not be_nil
    user.activation_state.should eq('pending')
    ActionMailer::Base.deliveries.count.should be > emails_count
  end

  it 'should handle invalid signups' do
    visit signup_path

    users_count = Coursewareable::User.count
    emails_count = ActionMailer::Base.deliveries.count

    within('#new_user') do
      fill_in 'user_email', :with => ''
      fill_in 'user_password', :with => ''
      fill_in 'user_password_confirmation', :with => ''
    end

    click_button 'submit_signup'

    page.should have_css('#notifications .alert-box')
    page.should have_css('#new_user .error.form-field')

    ActionMailer::Base.deliveries.count.should eq(emails_count)
    Coursewareable::User.count.should eq(users_count)
  end

  it 'should handle profile updates' do
    user = Fabricate(:confirmed_user)
    sign_in_with(user.email)

    visit me_users_url

    within('.edit_user') do
      fill_in 'user[first_name]', :with => 'Stas'
      fill_in 'user[last_name]', :with => 'Suscov'
    end

    click_button 'submit_profile'

    page.should have_css('#notifications .alert-box')

    user.reload
    user.first_name.should eq('Stas')
    user.last_name.should eq('Suscov')
  end

  it 'handles invitations' do
    user = Fabricate(:confirmed_user)
    sign_in_with(user.email)

    emails_count = ActionMailer::Base.deliveries.count
    visit invite_users_url

    within('#new_invitation') do
      fill_in 'email', :with => Faker::Internet.email
      fill_in 'message', :with => Faker::Lorem.paragraph
    end

    click_button 'submit_invitation'

    page.should have_css('#notifications .alert-box.success')
    ActionMailer::Base.deliveries.count.should eq(emails_count + 1)
  end

  it 'should be able to manage settings' do
    classroom = Fabricate('coursewareable/classroom')
    sign_in_with(classroom.owner.email)

    visit notifications_users_url

    page.should have_content(classroom.title.capitalize)
    page.should have_checked_field('memberships[1][email_announcement][send_grades]')
    page.uncheck('memberships[1][email_announcement][send_grades]')
    page.should have_button('Update')
    click_button('Update')

    page.should have_unchecked_field('memberships[1][email_announcement][send_grades]')
  end
end
