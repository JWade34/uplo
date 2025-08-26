class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    user = User.first || create_test_user
    UserMailer.welcome_email(user)
  end

  def getting_started_tips
    user = User.first || create_test_user
    UserMailer.getting_started_tips(user)
  end

  def common_mistakes
    user = User.first || create_test_user
    UserMailer.common_mistakes(user)
  end

  def success_stories
    user = User.first || create_test_user
    UserMailer.success_stories(user)
  end

  def final_conversion
    user = User.first || create_test_user
    UserMailer.final_conversion(user)
  end

  private

  def create_test_user
    User.new(
      id: 1,
      email_address: 'justin@example.com',
      unsubscribe_token: 'test-token-123'
    )
  end
end