# Single-user app: seed the one account. Override via env so no secret
# lands in the repo; the defaults are for throwaway development only.
User.find_or_create_by!(email_address: ENV.fetch("BUJO_EMAIL", "dev@example.com")) do |user|
  user.password = ENV.fetch("BUJO_PASSWORD", "changeme-dev-only")
end
