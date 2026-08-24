# Shared allowlist and persistence mechanics for device-local display choices.
module PreferenceCookies
  extend ActiveSupport::Concern

  private

  # Returns a stored choice only when it still belongs to the feature's allowlist.
  def stored_preference(cookie_name, allowed_values)
    value = cookies[cookie_name]
    value if allowed_values.include?(value)
  end

  # Stores allowlisted choices permanently and clears every default or invalid value.
  def store_preference_cookie(cookie_name, value, allowed_values)
    if allowed_values.include?(value)
      cookies.permanent[cookie_name] = { value: value, same_site: :lax }
    else
      cookies.delete(cookie_name)
    end
  end
end
