require "test_helper"

class CartPromoCodeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @cart = carts(:one) # products(:one) x 1 at 9.99
  end

  def auth_headers(user = @user)
    { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: user.id)}" }
  end

  def apply_code(code, user = @user)
    put "/api/cart/promo_code", params: { code: code }, headers: auth_headers(user), as: :json
  end

  def money(value)
    assert_kind_of String, value, "money values are serialized as strings"
    BigDecimal(value)
  end

  def body
    response.parsed_body
  end

  def assert_promo_error(error_code)
    assert_response :unprocessable_entity
    assert_equal error_code, body["error_code"]
    assert_equal PromoCode.error_message(error_code), body["error"]
  end

  # Cart response

  test "GET /api/cart returns the price breakdown and keeps the existing item shape" do
    get "/api/cart", headers: auth_headers

    assert_response :ok
    assert_equal %w[discount id items promo_code subtotal total], body.keys.sort
    assert_equal %w[id product quantity subtotal], body["items"].first.keys.sort
    assert_equal BigDecimal("9.99"), money(body["subtotal"])
    assert_equal BigDecimal("0"), money(body["discount"])
    assert_equal BigDecimal("9.99"), money(body["total"])
    assert_nil body["promo_code"]
  end

  # Applying codes

  test "applying a valid percentage code returns the discounted cart" do
    apply_code("TENOFF")

    assert_response :ok
    assert_equal BigDecimal("9.99"), money(body["subtotal"])
    assert_equal BigDecimal("1.00"), money(body["discount"])
    assert_equal BigDecimal("8.99"), money(body["total"])
    promo = body["promo_code"]
    assert_equal "TENOFF", promo["code"]
    assert_equal "percentage", promo["discount_type"]
    assert_equal BigDecimal("10"), money(promo["discount_value"])
    assert_equal true, promo["valid"]
    assert_nil promo["error_code"]
    assert_nil promo["message"]
    assert_equal promo_codes(:ten_percent), @cart.reload.promo_code
  end

  test "applying a valid fixed code returns the discounted cart" do
    apply_code("FIVEOFF")

    assert_response :ok
    assert_equal BigDecimal("5.00"), money(body["discount"])
    assert_equal BigDecimal("4.99"), money(body["total"])
  end

  test "a discount larger than the cart brings the total to zero" do
    apply_code("BIGFIXED")

    assert_response :ok
    assert_equal BigDecimal("9.99"), money(body["discount"])
    assert_equal BigDecimal("0"), money(body["total"])
  end

  test "entered codes are trimmed and matched case-insensitively" do
    apply_code("  fiveoff ")

    assert_response :ok
    assert_equal "FIVEOFF", body["promo_code"]["code"]
  end

  # Invalid codes

  test "a blank or missing code is rejected" do
    ["", "   ", nil].each do |code|
      apply_code(code)
      assert_promo_error "blank"
    end
    put "/api/cart/promo_code", params: {}, headers: auth_headers, as: :json
    assert_promo_error "blank"
    assert_nil @cart.reload.promo_code_id
  end

  test "an unknown code is rejected" do
    apply_code("NOSUCHCODE")
    assert_promo_error "not_found"
    assert_nil @cart.reload.promo_code_id
  end

  test "an expired code is rejected" do
    apply_code("EXPIRED")
    assert_promo_error "expired"
    assert_nil @cart.reload.promo_code_id
  end

  test "a deactivated code is rejected" do
    apply_code("INACTIVE")
    assert_promo_error "inactive"
    assert_nil @cart.reload.promo_code_id
  end

  # Replacing and removing

  test "applying another valid code replaces the current one" do
    apply_code("TENOFF")
    apply_code("FIVEOFF")

    assert_response :ok
    assert_equal "FIVEOFF", body["promo_code"]["code"]
    assert_equal promo_codes(:five_off), @cart.reload.promo_code
  end

  test "a failed replacement keeps the currently applied code" do
    apply_code("TENOFF")

    [["EXPIRED", "expired"], ["INACTIVE", "inactive"], ["NOSUCHCODE", "not_found"], ["", "blank"]].each do |code, error_code|
      apply_code(code)
      assert_promo_error error_code
      assert_equal promo_codes(:ten_percent), @cart.reload.promo_code
    end

    get "/api/cart", headers: auth_headers
    assert_equal "TENOFF", body["promo_code"]["code"]
    assert_equal BigDecimal("1.00"), money(body["discount"])
  end

  test "removing the code restores the undiscounted total" do
    apply_code("TENOFF")
    delete "/api/cart/promo_code", headers: auth_headers

    assert_response :ok
    assert_nil body["promo_code"]
    assert_equal BigDecimal("0"), money(body["discount"])
    assert_equal BigDecimal("9.99"), money(body["total"])
    assert_nil @cart.reload.promo_code_id
  end

  test "removing when no code is applied succeeds" do
    delete "/api/cart/promo_code", headers: auth_headers

    assert_response :ok
    assert_nil body["promo_code"]
  end

  # A code that becomes unusable after it was applied

  test "a code deactivated after being applied stays attached but gives no discount" do
    apply_code("TENOFF")
    promo_codes(:ten_percent).update!(active: false)

    get "/api/cart", headers: auth_headers

    assert_response :ok
    promo = body["promo_code"]
    assert_equal "TENOFF", promo["code"]
    assert_equal false, promo["valid"]
    assert_equal "inactive", promo["error_code"]
    assert_equal PromoCode.error_message(:inactive), promo["message"]
    assert_equal BigDecimal("0"), money(body["discount"])
    assert_equal BigDecimal("9.99"), money(body["total"])
  end

  test "a code that expires after being applied stays attached but gives no discount" do
    apply_code("FUTURE")
    assert_response :ok

    travel_to(promo_codes(:future).expires_at + 1.second) do
      get "/api/cart", headers: auth_headers # token issued at the travelled time

      assert_response :ok
      assert_equal "expired", body["promo_code"]["error_code"]
      assert_equal BigDecimal("0"), money(body["discount"])
    end
  end

  # Authentication and isolation

  test "promo code endpoints require authentication" do
    put "/api/cart/promo_code", params: { code: "TENOFF" }, as: :json
    assert_response :unauthorized

    delete "/api/cart/promo_code"
    assert_response :unauthorized

    assert_nil @cart.reload.promo_code_id
  end

  test "applying and removing codes only affects the signed-in user's cart" do
    other_user = users(:two)
    other_cart = carts(:two)

    apply_code("TENOFF")
    assert_nil other_cart.reload.promo_code_id

    get "/api/cart", headers: auth_headers(other_user)
    assert_equal other_cart.id, body["id"]
    assert_nil body["promo_code"]

    delete "/api/cart/promo_code", headers: auth_headers(other_user)
    assert_response :ok
    assert_equal promo_codes(:ten_percent), @cart.reload.promo_code
  end
end
