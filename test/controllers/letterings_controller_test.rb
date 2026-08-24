require "test_helper"

class LetteringsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "stores every explicit hand cookie" do
    %w[rock-salt architects-daughter patrick-hand gochi-hand sans].each do |hand|
      patch lettering_path, params: { hand: hand }

      assert_redirected_to root_path
      assert_equal hand, cookies[:hand]
      assert_match(/expires=/i, response.headers.fetch("Set-Cookie"))
      assert_match(/samesite=lax/i, response.headers.fetch("Set-Cookie"))
    end
  end

  test "marker clears the hand cookie" do
    patch lettering_path, params: { hand: "sans" }
    assert_equal "sans", cookies[:hand]

    patch lettering_path, params: { hand: "marker" }

    assert_redirected_to root_path
    assert_empty cookies[:hand]
  end

  test "an unrecognized hand clears the cookie" do
    patch lettering_path, params: { hand: "rock-salt" }
    assert_equal "rock-salt", cookies[:hand]

    patch lettering_path, params: { hand: "crafted-hand" }

    assert_redirected_to root_path
    assert_empty cookies[:hand]
  end
end
