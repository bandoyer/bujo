# Builds entry rows directly. No UI in the Daily Log slice creates a child or
# a second lifecycle state, so the fast lane makes those shapes itself.
module EntryTestHelper
  # Defaults to the suite's signed-in user, which each setup block assigns.
  def create_open_task(text, page_on:, page_kind: "daily", parent: nil, user: @user)
    user.entries.create!(
      kind: "task",
      state: "open",
      text: text,
      tags: [],
      page_kind: page_kind,
      page_on: page_on,
      parent: parent
    )
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include EntryTestHelper
end
