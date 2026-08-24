require "date"

module Bujo
  # Parses and canonically renders the one-line rapid-log grammar.
  module RapidLog
    # Immutable result of parsing one rapid-log line.
    Parsed = Data.define(:kind, :state, :priority, :text, :date, :time, :tags, :raw)

    DEFAULT_KINDS = %i[task event note].freeze
    GLYPHS = {
      "•" => %i[task open],
      "." => %i[task open],
      "x" => %i[task done],
      "X" => %i[task done],
      "○" => [ :event, nil ],
      "o" => [ :event, nil ],
      "O" => [ :event, nil ],
      "–" => [ :note, nil ],
      "-" => [ :note, nil ]
    }.freeze
    GLYPH_PATTERN = Regexp.union(GLYPHS.keys).freeze
    TAG_PATTERN = /(?:\A|(?<=\s))\+([A-Za-z0-9_-]+)\z/
    TWENTY_FOUR_HOUR_PATTERN = /(?:\A|(?<=\s))([01]?\d|2[0-3]):([0-5]\d)\z/
    TWELVE_HOUR_PATTERN = /(?:\A|(?<=\s))(0?[1-9]|1[0-2])(?::([0-5]\d))?(am|pm)\z/i
    ISO_DATE_PATTERN = /(?:\A|(?<=\s))(\d{4})-(\d{2})-(\d{2})\z/
    MONTHS = {
      "jan" => 1, "january" => 1,
      "feb" => 2, "february" => 2,
      "mar" => 3, "march" => 3,
      "apr" => 4, "april" => 4,
      "may" => 5,
      "jun" => 6, "june" => 6,
      "jul" => 7, "july" => 7,
      "aug" => 8, "august" => 8,
      "sep" => 9, "september" => 9,
      "oct" => 10, "october" => 10,
      "nov" => 11, "november" => 11,
      "dec" => 12, "december" => 12
    }.freeze
    MONTH_NAMES_PATTERN = MONTHS.keys.sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }.join("|")
    MONTH_DAY_PATTERN = /(?:\A|(?<=\s))(#{MONTH_NAMES_PATTERN})\s+([1-9]|[12]\d|3[01])\z/i
    WEEKDAYS = {
      "sun" => 0, "sunday" => 0,
      "mon" => 1, "monday" => 1,
      "tue" => 2, "tuesday" => 2,
      "wed" => 3, "wednesday" => 3,
      "thu" => 4, "thursday" => 4,
      "fri" => 5, "friday" => 5,
      "sat" => 6, "saturday" => 6
    }.freeze
    WEEKDAY_NAMES_PATTERN = WEEKDAYS.keys.sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }.join("|")
    WEEKDAY_PATTERN = /(?:\A|(?<=\s))(?:#{WEEKDAY_NAMES_PATTERN})\z/i
    RELATIVE_DATE_PATTERN = /(?:\A|(?<=\s))(?:today|tomorrow)\z/i
    DAY_NUMBERS = (1..31).to_h { |day| [ day.to_s, day ] }.freeze
    MAXIMUM_MONTH_DAYS = [ nil, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ].freeze
    RENDER_GLYPHS = {
      [ :task, :open ] => "•",
      [ :task, :done ] => "x",
      [ :event, nil ] => "○",
      [ :note, nil ] => "–"
    }.freeze

    class << self
      # Parses +line+ using the caller-provided date for relative expressions.
      def parse(line, today:, default_kind: :task)
        validate_default_kind!(default_kind)
        raw = line.to_s.scrub
        content = raw.strip

        content, kind, state, priority = consume_prefix(content, default_kind)
        text, date, time, tags = consume_end_zone(content, today)
        return if text.empty?

        Parsed.new(
          kind: kind,
          state: state,
          priority: priority,
          text: text,
          date: date,
          time: time,
          tags: tags,
          raw: raw
        )
      end

      # Renders a parsed line in stable glyph, tag, ISO-date, and time order.
      def render(parsed)
        tokens = [ render_glyph(parsed), parsed.text ]
        tokens.concat(parsed.tags.map { |tag| "+#{tag}" })
        tokens << parsed.date if parsed.date
        tokens << parsed.time if parsed.time

        "#{"* " if parsed.priority}#{tokens.join(" ")}"
      end

      private

      def validate_default_kind!(default_kind)
        return if DEFAULT_KINDS.include?(default_kind)

        raise ArgumentError
      end

      def consume_prefix(content, default_kind)
        content, priority = consume_priority(content)
        match = content.match(/\A(#{GLYPH_PATTERN})(?:\s+|\z)/)
        return default_prefix(content, default_kind, priority) unless match

        kind, state = GLYPHS.fetch(match[1])
        [ match.post_match, kind, state, priority ]
      end

      def consume_priority(content)
        match = content.match(/\A\*(?:\s+|\z)/)
        return [ content, false ] unless match

        [ match.post_match, true ]
      end

      def default_prefix(content, default_kind, priority)
        state = :open if default_kind == :task
        [ content, default_kind, state, priority ]
      end

      def consume_end_zone(content, today)
        content, later_tags = consume_tags(content)
        time_result = consume_time(content)
        content = time_result.fetch(0)
        time = time_result.fetch(1)
        date_result = consume_date(content, today)
        content = date_result.fetch(0)
        date = date_result.fetch(1)
        content, earlier_tags = consume_tags(content)
        tags = unique_tags(earlier_tags + later_tags)

        [ content, date, time, tags ]
      end

      def consume_tags(content)
        tags = []
        while (match = content.match(TAG_PATTERN))
          tags.unshift(match[1].downcase)
          content = before_match(match)
        end

        [ content, tags ]
      end

      def consume_time(content)
        if (match = content.match(TWENTY_FOUR_HOUR_PATTERN))
          return [ before_match(match), format("%02d:%02d", match[1], match[2]) ]
        end

        match = content.match(TWELVE_HOUR_PATTERN)
        return [ content, nil ] unless match

        hour = Integer(match[1], 10) % 12
        hour += 12 if match[3].casecmp?("pm")
        [ before_match(match), format("%02d:%02d", hour, match[2] || 0) ]
      end

      def consume_date(content, today)
        match = content.match(ISO_DATE_PATTERN)
        return consume_iso_date(match) if match

        match = content.match(MONTH_DAY_PATTERN)
        return consume_month_day(match, today) if match

        match = content.match(WEEKDAY_PATTERN)
        return consume_weekday(match, today) if match

        match = content.match(RELATIVE_DATE_PATTERN)
        return consume_relative_date(match, today) if match

        [ content, nil ]
      end

      def consume_iso_date(match)
        [ before_match(match), Date.iso8601(match[0]) ]
      rescue Date::Error
        [ match.string, nil ]
      end

      def consume_month_day(match, today)
        month = MONTHS.fetch(match[1].downcase)
        day = DAY_NUMBERS.fetch(match[2])
        date = next_month_day(today, month, day)
        return [ match.string, nil ] unless date

        [ before_match(match), date ]
      end

      def consume_weekday(match, today)
        weekday = WEEKDAYS.fetch(match[0].downcase)
        days_ahead = (weekday - today.wday) % 7
        [ before_match(match), today + days_ahead ]
      end

      def consume_relative_date(match, today)
        days_ahead = match[0].casecmp?("tomorrow") ? 1 : 0
        [ before_match(match), today + days_ahead ]
      end

      def valid_date(year, month, day)
        Date.new(year, month, day)
      rescue Date::Error
        nil
      end

      def next_month_day(today, month, day)
        return if day > MAXIMUM_MONTH_DAYS.fetch(month)

        year = today.year
        loop do
          date = valid_date(year, month, day)
          return date if date && date >= today

          year += 1
        end
      end

      def unique_tags(tags)
        tags.each_with_object([]) do |tag, unique|
          unique << tag unless unique.include?(tag)
        end
      end

      def before_match(match)
        match.pre_match.rstrip
      end

      def render_glyph(parsed)
        RENDER_GLYPHS.fetch([ parsed.kind, parsed.state ])
      end
    end

    private_constant :DEFAULT_KINDS, :GLYPHS, :GLYPH_PATTERN, :TAG_PATTERN,
      :TWENTY_FOUR_HOUR_PATTERN, :TWELVE_HOUR_PATTERN, :ISO_DATE_PATTERN,
      :MONTHS, :MONTH_NAMES_PATTERN, :MONTH_DAY_PATTERN, :WEEKDAYS,
      :WEEKDAY_NAMES_PATTERN, :WEEKDAY_PATTERN,
      :RELATIVE_DATE_PATTERN, :DAY_NUMBERS, :MAXIMUM_MONTH_DAYS,
      :RENDER_GLYPHS
  end
end
