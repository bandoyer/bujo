# The signed-in reader's entry relation, shared by every journal screen.
module JournalReading
  extend ActiveSupport::Concern

  private

  # Every log query begins from the authenticated user's journal.
  def user_entries
    Current.user.entries
  end
end
