# Delivers a fresh magic-link token only while the queued generation is current.
class MagicLinkDeliveryJob < ApplicationJob
  # Delivers synchronously inside the queue job so provider failures remain visible.
  def perform(user_id, magic_link_version)
    user = User.find_by(id: user_id, magic_link_version: magic_link_version)
    return unless user

    token = user.generate_token_for(:magic_link)
    MagicLinksMailer.sign_in(user, token).deliver_now!
  end
end
