require "test_helper"

class CartTest < ActiveSupport::TestCase
  setup do
    @cart = carts(:one) # contains products(:one) x 1 at 9.99
  end

  test "subtotal uses current prices and quantities as BigDecimal" do
    CartItem.create!(cart: @cart, product: products(:two), quantity: 1)
    assert_equal BigDecimal("19.98"), @cart.subtotal
    assert_kind_of BigDecimal, @cart.subtotal
  end

  test "an empty cart has a zero subtotal and total" do
    @cart.cart_items.destroy_all
    assert_equal BigDecimal("0"), @cart.subtotal
    assert_equal BigDecimal("0"), @cart.total
  end

  test "without a promo code the total equals the subtotal" do
    breakdown = @cart.price_breakdown
    assert_equal BigDecimal("9.99"), breakdown[:subtotal]
    assert_equal BigDecimal("0"), breakdown[:discount]
    assert_equal BigDecimal("9.99"), breakdown[:total]
    breakdown.each_value { |amount| assert_kind_of BigDecimal, amount }
  end

  test "a usable percentage code discounts the total" do
    @cart.update!(promo_code: promo_codes(:ten_percent))
    assert_equal BigDecimal("1.00"), @cart.discount_amount
    assert_equal BigDecimal("8.99"), @cart.total
  end

  test "a fixed discount larger than the subtotal brings the total to zero, never below" do
    @cart.update!(promo_code: promo_codes(:big_fixed))
    assert_equal BigDecimal("9.99"), @cart.discount_amount
    assert_equal BigDecimal("0"), @cart.total
  end

  test "an expired or inactive code stays attached but gives no discount" do
    %i[expired inactive].each do |name|
      @cart.update!(promo_code: promo_codes(name))
      assert_equal promo_codes(name), @cart.reload.promo_code
      assert_equal BigDecimal("0"), @cart.discount_amount
      assert_equal BigDecimal("9.99"), @cart.total
    end
  end

  test "deleting a promo code clears it from carts" do
    code = PromoCode.create!(code: "TEMP", discount_type: "fixed", discount_value: 1)
    @cart.update!(promo_code: code)
    code.destroy
    assert_nil @cart.reload.promo_code_id
  end
end
