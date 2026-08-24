require "test_helper"
require "bujo/rapid_log"

class RapidLogParseTest < ActiveSupport::TestCase
  cover "Bujo::RapidLog*"

  TODAY = Date.new(2026, 8, 24)
  RULED_CASES = [
    [ "Review the auth PR +work", :task, :open, false, "Review the auth PR", nil, nil, %w[work] ],
    [ "* • Ship bujo v0.1", :task, :open, true, "Ship bujo v0.1", nil, nil, [] ],
    [ "x Email Sarah the invoice", :task, :done, false, "Email Sarah the invoice", nil, nil, [] ],
    [ "o Dinner w/ Lena tomorrow 6pm", :event, nil, false, "Dinner w/ Lena", Date.new(2026, 8, 25), "18:00", [] ],
    [ "○ RVA Ruby meetup sep 2 18:30", :event, nil, false, "RVA Ruby meetup", Date.new(2026, 9, 2), "18:30", [] ],
    [ "– idea: one parser everywhere", :note, nil, false, "idea: one parser everywhere", nil, nil, [] ],
    [ "- pick up dry cleaning", :note, nil, false, "pick up dry cleaning", nil, nil, [] ],
    [ "call the vet friday", :task, :open, false, "call the vet", Date.new(2026, 8, 28), nil, [] ],
    [ "renew passport jan 5", :task, :open, false, "renew passport", Date.new(2027, 1, 5), nil, [] ],
    [ "pay invoice 2026-08-30", :task, :open, false, "pay invoice", Date.new(2026, 8, 30), nil, [] ],
    [ "buy fuel +camping +errands", :task, :open, false, "buy fuel", nil, nil, %w[camping errands] ],
    [ "call vet +home tomorrow", :task, :open, false, "call vet", Date.new(2026, 8, 25), nil, %w[home] ],
    [ "standup 2pm", :task, :open, false, "standup", nil, "14:00", [] ],
    [ "xylophone practice", :task, :open, false, "xylophone practice", nil, nil, [] ],
    [ "party feb 30", :task, :open, false, "party feb 30", nil, nil, [] ],
    [ "x o meeting", :task, :done, false, "o meeting", nil, nil, [] ],
    [ ". tune bike brakes", :task, :open, false, "tune bike brakes", nil, nil, [] ],
    [ "monday", nil, nil, false, nil, nil, nil, [] ],
    [ "   ", nil, nil, false, nil, nil, nil, [] ],
    [ "o standup", :event, nil, false, "standup", nil, nil, [] ]
  ].freeze
  DEFAULT_KIND_OVERRIDES = { "o standup" => :note }.freeze

  # The default kind a ruled row is parsed with; rows are tasks unless the
  # table row exists to prove a glyph overrides a different default.
  def self.default_kind_for(input)
    DEFAULT_KIND_OVERRIDES.fetch(input, :task)
  end

  test "parses every ruled example" do
    RULED_CASES.each_with_index do |(input, kind, state, priority, text, date, time, tags), index|
      default_kind = RapidLogParseTest.default_kind_for(input)
      parsed = Bujo::RapidLog.parse(input, today: TODAY, default_kind: default_kind)

      if kind
        values = Bujo::RapidLog::Parsed.members.map { |member| parsed.public_send(member) }
        assert_equal [ kind, state, priority, text, date, time, tags, input ], values, "row #{index + 1}"
      else
        assert_nil parsed, "row #{index + 1}"
      end
    end
  end

  test "recognizes every glyph and ASCII alias" do
    {
      "•" => [ :task, :open ],
      "." => [ :task, :open ],
      "x" => [ :task, :done ],
      "X" => [ :task, :done ],
      "○" => [ :event, nil ],
      "o" => [ :event, nil ],
      "O" => [ :event, nil ],
      "–" => [ :note, nil ],
      "-" => [ :note, nil ]
    }.each do |glyph, (kind, state)|
      parsed = Bujo::RapidLog.parse("#{glyph} words", today: TODAY)

      assert_equal [ kind, state, "words" ], [ parsed.kind, parsed.state, parsed.text ], glyph
    end
  end

  test "only treats a leading whitespace-delimited glyph as a prefix" do
    [ "xylophone", ".gitignore", "-dash", "opal" ].each do |text|
      parsed = Bujo::RapidLog.parse(text, today: TODAY)

      assert_equal [ :task, :open, text ], [ parsed.kind, parsed.state, parsed.text ]
    end

    parsed = Bujo::RapidLog.parse("  X finished  ", today: TODAY)
    assert_equal [ :task, :done, "finished", "  X finished  " ], [ parsed.kind, parsed.state, parsed.text, parsed.raw ]

    spaced = Bujo::RapidLog.parse("  X   widely spaced  ", today: TODAY)
    assert_equal "widely spaced", spaced.text
  end

  test "recognizes a leading priority signifier alone or before one glyph" do
    alone = Bujo::RapidLog.parse("* important", today: TODAY, default_kind: :note)
    with_glyph = Bujo::RapidLog.parse("* O launch", today: TODAY)
    later = Bujo::RapidLog.parse("read * carefully", today: TODAY)
    second_glyph = Bujo::RapidLog.parse("x o meeting", today: TODAY)
    spaced = Bujo::RapidLog.parse("*   important", today: TODAY)

    assert_equal [ :note, nil, true, "important" ], [ alone.kind, alone.state, alone.priority, alone.text ]
    assert_equal [ :event, nil, true, "launch" ], [ with_glyph.kind, with_glyph.state, with_glyph.priority, with_glyph.text ]
    assert_equal [ false, "read * carefully" ], [ later.priority, later.text ]
    assert_equal [ :done, "o meeting" ], [ second_glyph.state, second_glyph.text ]
    assert_equal [ true, "important" ], [ spaced.priority, spaced.text ]
  end

  test "uses the validated default kind when no glyph is present" do
    event = Bujo::RapidLog.parse("appointment", today: TODAY, default_kind: :event)
    note = Bujo::RapidLog.parse("thought", today: TODAY, default_kind: :note)

    assert_equal [ :event, nil ], [ event.kind, event.state ]
    assert_equal [ :note, nil ], [ note.kind, note.state ]
    assert_raises(ArgumentError) { Bujo::RapidLog.parse("words", today: TODAY, default_kind: :bogus) }
    assert_raises(ArgumentError) { Bujo::RapidLog.parse("x words", today: TODAY, default_kind: nil) }
  end

  test "leaves migration and scheduling markers in ordinary text" do
    [ "> migrated", "< scheduled" ].each do |text|
      parsed = Bujo::RapidLog.parse(text, today: TODAY)

      assert_equal [ :task, :open, text ], [ parsed.kind, parsed.state, parsed.text ]
    end
  end

  test "consumes tags around date and time in appearance order" do
    parsed = Bujo::RapidLog.parse("call +Home tomorrow 9:30 +WORK +home", today: TODAY)

    assert_equal "call", parsed.text
    assert_equal Date.new(2026, 8, 25), parsed.date
    assert_equal "09:30", parsed.time
    assert_equal %w[home work], parsed.tags
  end

  test "keeps invalid and non-trailing tags in text" do
    punctuation = Bujo::RapidLog.parse("file +work.", today: TODAY)
    embedded = Bujo::RapidLog.parse("ask +friend today please", today: TODAY)

    assert_equal [ "file +work.", [] ], [ punctuation.text, punctuation.tags ]
    assert_equal [ "ask +friend today please", [] ], [ embedded.text, embedded.tags ]
  end

  test "normalizes valid 24-hour and am-pm times and retains invalid times" do
    {
      "at midnight 12am" => [ "at midnight", "00:00" ],
      "at noon 12PM" => [ "at noon", "12:00" ],
      "morning 9am" => [ "morning", "09:00" ],
      "evening 09pm" => [ "evening", "21:00" ],
      "evening 11:59pm" => [ "evening", "23:59" ],
      "evening 11:09pm" => [ "evening", "23:09" ],
      "morning 11:08am" => [ "morning", "11:08" ],
      "morning 1:09am" => [ "morning", "01:09" ],
      "meet 0:00" => [ "meet", "00:00" ],
      "meet 9:30" => [ "meet", "09:30" ],
      "meet 09:30" => [ "meet", "09:30" ],
      "meet 14:08" => [ "meet", "14:08" ],
      "meet 14:09" => [ "meet", "14:09" ],
      "meet 23:59" => [ "meet", "23:59" ],
      "meet 24:00" => [ "meet 24:00", nil ],
      "meet 9:5" => [ "meet 9:5", nil ],
      "meet 13pm" => [ "meet 13pm", nil ]
    }.each do |input, (text, time)|
      parsed = Bujo::RapidLog.parse(input, today: TODAY)

      assert_equal [ text, time ], [ parsed.text, parsed.time ], input
    end
  end

  test "resolves all supported dates against today" do
    {
      "task today" => Date.new(2026, 8, 24),
      "task tomorrow" => Date.new(2026, 8, 25),
      "task mon" => Date.new(2026, 8, 24),
      "task Monday" => Date.new(2026, 8, 24),
      "task fri" => Date.new(2026, 8, 28),
      "task Friday" => Date.new(2026, 8, 28),
      "task sunday" => Date.new(2026, 8, 30),
      "task aug 24" => Date.new(2026, 8, 24),
      "task August 24" => Date.new(2026, 8, 24),
      "task aug 23" => Date.new(2027, 8, 23),
      "task feb 29" => Date.new(2028, 2, 29),
      "task 2025-01-02" => Date.new(2025, 1, 2),
      "task 0008-08-09" => Date.new(8, 8, 9),
      "task 2026-10-08" => Date.new(2026, 10, 8)
    }.each do |input, date|
      parsed = Bujo::RapidLog.parse(input, today: TODAY)

      assert_equal [ "task", date ], [ parsed.text, parsed.date ], input
    end
  end

  test "retains invalid dates and times that precede a trailing date" do
    [ "party feb 30", "party 2026-02-30", "party 2026-13-01" ].each do |input|
      parsed = Bujo::RapidLog.parse(input, today: TODAY)

      assert_equal [ input, nil ], [ parsed.text, parsed.date ]
    end

    parsed = Bujo::RapidLog.parse("appointment 14:00 sep 9", today: TODAY)
    assert_equal [ "appointment 14:00", Date.new(2026, 9, 9), nil ], [ parsed.text, parsed.date, parsed.time ]
  end

  test "returns nil whenever prefix and end-zone removal leaves no text" do
    [ "today", "monday", "+home", "x ", "*", "* • tomorrow +work" ].each do |input|
      assert_nil Bujo::RapidLog.parse(input, today: TODAY), input
    end
  end

  test "normalizes non-string input and strips only the parsed text" do
    number = Bujo::RapidLog.parse(123, today: TODAY)
    spaced = Bujo::RapidLog.parse("  plain words  ", today: TODAY)

    assert_equal [ "123", "123" ], [ number.text, number.raw ]
    assert_equal [ "plain words", "  plain words  " ], [ spaced.text, spaced.raw ]
  end

  test "scrubs malformed input without changing raw whitespace" do
    malformed = "  note x here  ".dup
    malformed.setbyte(7, 0xFF)
    parsed = Bujo::RapidLog.parse(malformed, today: TODAY)

    assert_equal "note � here", parsed.text
    assert_equal "  note � here  ", parsed.raw
    assert_predicate parsed.raw, :valid_encoding?
  end

  test "forces BINARY input to UTF-8 without mutating the caller's string" do
    malformed = "  note x here  ".b
    malformed.setbyte(7, 0xFF)
    original_bytes = malformed.bytes

    parsed = Bujo::RapidLog.parse(malformed, today: TODAY)

    assert_equal "note � here", parsed.text
    assert_equal "  note � here  ", parsed.raw
    assert_equal Encoding::UTF_8, parsed.raw.encoding
    assert_equal Encoding::ASCII_8BIT, malformed.encoding
    assert_equal original_bytes, malformed.bytes
  end
end

class RapidLogRenderTest < ActiveSupport::TestCase
  cover "Bujo::RapidLog*"

  TODAY = RapidLogParseTest::TODAY

  test "renders every kind in canonical token order" do
    cases = [
      [ [ :task, :open, false ], "• words +home +work 2026-09-02 09:05" ],
      [ [ :task, :done, true ], "* x words +home +work 2026-09-02 09:05" ],
      [ [ :event, nil, false ], "○ words +home +work 2026-09-02 09:05" ],
      [ [ :note, nil, true ], "* – words +home +work 2026-09-02 09:05" ]
    ]

    cases.each do |((kind, state, priority), expected)|
      parsed = Bujo::RapidLog::Parsed.new(
        kind: kind,
        state: state,
        priority: priority,
        text: "words",
        date: Date.new(2026, 9, 2),
        time: "09:05",
        tags: %w[home work],
        raw: "ignored"
      )

      assert_equal expected, Bujo::RapidLog.render(parsed)
    end
  end

  test "omits absent optional tokens without trailing separators" do
    parsed = Bujo::RapidLog::Parsed.new(
      kind: :task,
      state: :open,
      priority: false,
      text: "words",
      date: nil,
      time: nil,
      tags: [],
      raw: "ignored"
    )

    assert_equal "• words", Bujo::RapidLog.render(parsed)
  end

  test "round trips every nonblank ruled example except raw" do
    RapidLogParseTest::RULED_CASES.each_with_index do |(input, kind, *), index|
      next unless kind

      default_kind = RapidLogParseTest.default_kind_for(input)
      original = Bujo::RapidLog.parse(input, today: TODAY, default_kind: default_kind)
      reparsed = Bujo::RapidLog.parse(Bujo::RapidLog.render(original), today: Date.new(2040, 1, 1))

      assert_equal original.to_h.except(:raw), reparsed.to_h.except(:raw), "row #{index + 1}"
    end
  end
end
