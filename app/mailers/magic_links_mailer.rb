# Builds the multipart, scanner-safe existing-account sign-in message.
class MagicLinksMailer < ApplicationMailer
  # Places the bearer only in the fragment of the configured canonical URL.
  def sign_in(user, token)
    @magic_link_url = open_sign_in_link_url(anchor: token)
    mail(to: user.email_address, subject: "Your Bujo sign-in link")
  end
end
