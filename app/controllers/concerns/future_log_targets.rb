# The DOM ids a Future Log month owns, named once because two controllers
# must agree on them. FutureLogsController renders the container; the Turbo
# Stream that appends to it after a month-header capture is rendered by
# EntriesController. Turbo drops a stream action whose target is missing
# without raising, so a disagreement costs the reader a Log button that does
# nothing at all - no row, no error, no clue.
module FutureLogTargets
  extend ActiveSupport::Concern

  included do
    helper_method :future_month_entries_id
  end

  private

  # Where a month's entries are appended. Any date within the month answers
  # the same id, so the runway's first-of-month and a capture's chosen day
  # both address the same container.
  def future_month_entries_id(month)
    "future_month_entries_#{month.strftime('%Y_%m')}"
  end
end
