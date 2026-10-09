require "test_helper"

class CartItemsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @cart = carts(:one)
    @headers = { "Authorization" => "Bearer #{JsonWebToken.encode(user_id: @user.id)}" }
    @product = Product.create!(name: "Leash", price: 5, stock_quantity: 5)
  end

  def add_item(product, quantity = nil)
    params = { product_id: product.id }
    params[:quantity] = quantity if quantity
    post "/api/cart/items", params: params, headers: @headers, as: :json
  end

  def quantity_in_cart(product)
    @cart.cart_items.find_by(product: product)&.quantity
  end

  test "adding a new product uses exactly the requested quantity" do
    add_item(@product, 2)

    assert_response :ok
    assert_equal 2, quantity_in_cart(@product)
  end

  test "adding a new product without a quantity adds one" do
    add_item(@product)

    assert_response :ok
    assert_equal 1, quantity_in_cart(@product)
  end

  test "adding a product already in the cart increases its quantity" do
    add_item(@product, 2)
    add_item(@product, 1)

    assert_response :ok
    assert_equal 3, quantity_in_cart(@product)
  end

  test "the last unit in stock can be added" do
    product = products(:two) # stock 1, not in this cart

    add_item(product, 1)

    assert_response :ok
    assert_equal 1, quantity_in_cart(product)
  end
end
