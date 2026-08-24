require "test_helper"

class ThemesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
  end

  test "sets explicit theme cookies" do
    %w[light dark].each do |theme|
      patch theme_path, params: { theme: theme }

      assert_redirected_to root_path
      assert_equal theme, cookies[:theme]
    end
  end

  test "system preference clears the theme cookie" do
    patch theme_path, params: { theme: "dark" }
    assert_equal "dark", cookies[:theme]

    patch theme_path, params: { theme: "system" }

    assert_redirected_to root_path
    assert_empty cookies[:theme]
  end
end
