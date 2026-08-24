require "securerandom"

module UuidV7Id
  extend ActiveSupport::Concern

  included do
    before_create { self.id ||= SecureRandom.uuid_v7 }
  end
end
