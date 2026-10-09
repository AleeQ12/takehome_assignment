require "test_helper"
require "minitest/mock"

class OrdersTest < ActionDispatch::IntegrationTest
  ORDER_KEYS = %w[created_at discount_amount id promo_code status subtotal_amount total_amount].freeze

  setup do
    @user = users(:one)
    @cart = carts(:one) # products(:one) x 1 at 9.99, stock 1
    @headers = auth_headers
  end

  def auth_headers(user = @user)
    { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: user.id)}" }
  end

  def body
    response.parsed_body
  end

  def money(value)
    assert_kind_of String, value, "money values are serialized as strings"
    BigDecimal(value)
  end

  def checkout(headers = @headers)
    post "/api/orders", headers: headers
  end

  # Asserts that a failed checkout left orders, stock and the cart exactly as they were.
  def assert_checkout_left_everything_unchanged(promo_code:, cart_item_count: 1)
    stock_before = Product.order(:id).pluck(:id, :stock_quantity)
    assert_no_difference ["Order.count", "OrderItem.count"] do
      yield
    end
    assert_response :unprocessable_entity
    assert_equal stock_before, Product.order(:id).pluck(:id, :stock_quantity)
    assert_equal cart_item_count, @cart.reload.cart_items.count
    assert_equal promo_code, @cart.promo_code
  end

  # Order history

  test "GET /api/orders returns the current user's orders with items" do
    get "/api/orders", headers: @headers

    assert_response :ok
    assert_equal [orders(:one).id], body.map { |o| o["id"] }

    order = body.first
    assert_equal (ORDER_KEYS + ["items"]).sort, order.keys.sort
    assert_equal "9.99", order["total_amount"]
    assert_equal BigDecimal("9.99"), money(order["subtotal_amount"])
    assert_equal BigDecimal("0"), money(order["discount_amount"])
    assert_nil order["promo_code"]
    assert_equal 1, order["items"].length
    assert_equal %w[price product_name quantity subtotal], order["items"].first.keys.sort
  end

  test "GET /api/orders requires authentication" do
    get "/api/orders"

    assert_response :unauthorized
  end

  test "order history returns persisted amounts, not recalculated ones" do
    @cart.update!(promo_code: promo_codes(:ten_percent))
    checkout
    assert_response :created
    order_id = body["id"]

    # Later changes to the code and the product price must not alter the recorded order.
    promo_codes(:ten_percent).update!(active: false)
    products(:one).update!(price: 20)

    get "/api/orders", headers: @headers
    order = body.find { |o| o["id"] == order_id }
    assert_equal BigDecimal("9.99"), money(order["subtotal_amount"])
    assert_equal BigDecimal("1.00"), money(order["discount_amount"])
    assert_equal BigDecimal("8.99"), money(order["total_amount"])
    assert_equal "TENOFF", order["promo_code"]
    assert_equal BigDecimal("9.99"), money(order["items"].first["price"])
  end

  # Checkout without a code

  test "POST /api/orders creates an order from the cart and empties it" do
    assert_equal 1, @cart.cart_items.count

    assert_difference -> { @user.orders.count }, 1 do
      checkout
    end

    assert_response :created
    assert_equal ORDER_KEYS, body.keys.sort
    assert_equal "9.99", body["total_amount"]
    assert_equal BigDecimal("9.99"), money(body["subtotal_amount"])
    assert_equal BigDecimal("0"), money(body["discount_amount"])
    assert_nil body["promo_code"]
    assert_equal "pending", body["status"]

    order = Order.find(body["id"])
    assert_equal 1, order.order_items.count
    assert_nil order.promo_code
    assert_equal 0, products(:one).reload.stock_quantity
    assert_equal 0, @cart.reload.cart_items.count
  end

  test "checkout with an empty cart is rejected" do
    @cart.cart_items.destroy_all

    assert_no_difference "Order.count" do
      checkout
    end
    assert_response :unprocessable_entity
    assert_equal "Cart is empty", body["error"]
  end

  # Checkout with a code

  test "checkout with a valid code persists the discounted amounts and clears the cart" do
    @cart.update!(promo_code: promo_codes(:ten_percent))

    assert_difference ["Order.count", "OrderItem.count"], 1 do
      checkout
    end

    assert_response :created
    assert_equal ORDER_KEYS, body.keys.sort
    assert_equal BigDecimal("9.99"), money(body["subtotal_amount"])
    assert_equal BigDecimal("1.00"), money(body["discount_amount"])
    assert_equal BigDecimal("8.99"), money(body["total_amount"])
    assert_equal "TENOFF", body["promo_code"]

    order = Order.find(body["id"])
    assert_equal promo_codes(:ten_percent), order.promo_code
    assert_equal BigDecimal("9.99"), order.subtotal_amount
    assert_equal BigDecimal("1.00"), order.discount_amount
    assert_equal BigDecimal("8.99"), order.total_amount
    assert_equal BigDecimal("9.99"), order.order_items.first.price
    assert_equal 0, products(:one).reload.stock_quantity
    assert_equal 0, @cart.reload.cart_items.count
    assert_nil @cart.promo_code
  end

  test "checkout through the cart API uses the code applied there" do
    put "/api/cart/promo_code", params: { code: "fiveoff" }, headers: @headers, as: :json
    assert_response :ok

    checkout

    assert_response :created
    assert_equal BigDecimal("5.00"), money(body["discount_amount"])
    assert_equal BigDecimal("4.99"), money(body["total_amount"])
    assert_equal "FIVEOFF", body["promo_code"]
  end

  test "a discount covering the whole cart creates a zero-total order" do
    @cart.update!(promo_code: promo_codes(:big_fixed))

    checkout

    assert_response :created
    assert_equal BigDecimal("9.99"), money(body["discount_amount"])
    assert_equal BigDecimal("0"), money(body["total_amount"])
    assert_equal BigDecimal("0"), Order.find(body["id"]).total_amount
  end

  # Code invalidated between preview and checkout

  test "checkout is rejected when the applied code was deactivated, leaving everything unchanged" do
    @cart.update!(promo_code: promo_codes(:ten_percent))
    promo_codes(:ten_percent).update!(active: false)

    assert_checkout_left_everything_unchanged(promo_code: promo_codes(:ten_percent)) { checkout }
    assert_equal "inactive", body["error_code"]
    assert_includes body["error"], PromoCode.error_message(:inactive)
  end

  test "checkout is rejected when the applied code expired after it was applied" do
    @cart.update!(promo_code: promo_codes(:future))

    travel_to(promo_codes(:future).expires_at + 1.second) do
      assert_checkout_left_everything_unchanged(promo_code: promo_codes(:future)) { checkout(auth_headers) }
      assert_equal "expired", body["error_code"]
    end
  end

  # Atomicity

  test "a stock failure after earlier writes rolls back the whole checkout" do
    @cart.update!(promo_code: promo_codes(:ten_percent))
    CartItem.create!(cart: @cart, product: products(:two), quantity: 1)
    # Stock drops after the item was added; checkout writes the order and the first
    # item before this product's stock update fails.
    products(:two).update_column(:stock_quantity, 0)

    assert_checkout_left_everything_unchanged(promo_code: promo_codes(:ten_percent), cart_item_count: 2) { checkout }
    assert_equal "insufficient_stock", body["error_code"]
    assert_equal "Not enough stock for #{products(:two).name}.", body["error"]
  end

  test "unexpected errors are not swallowed and still roll back" do
    stock_before = products(:one).stock_quantity

    OrderItem.stub(:create!, ->(*_args, **_kwargs) { raise "unexpected failure" }) do
      assert_no_difference "Order.count" do
        assert_raises(RuntimeError) { checkout }
      end
    end

    assert_equal stock_before, products(:one).reload.stock_quantity
    assert_equal 1, @cart.reload.cart_items.count
  end
end
