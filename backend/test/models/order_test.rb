require "test_helper"

class OrderTest < ActiveSupport::TestCase
  def build_order(attrs = {})
    Order.new({ user: users(:one), status: "pending",
                subtotal_amount: BigDecimal("10.00"), discount_amount: BigDecimal("1.00"),
                total_amount: BigDecimal("9.00") }.merge(attrs))
  end

  test "is valid when total equals subtotal minus discount" do
    assert build_order.valid?
  end

  test "allows a zero total when the discount covers the subtotal" do
    assert build_order(discount_amount: BigDecimal("10.00"), total_amount: BigDecimal("0")).valid?
  end

  test "rejects a total that does not equal subtotal minus discount" do
    order = build_order(total_amount: BigDecimal("10.00"))
    assert_not order.valid?
    assert_includes order.errors[:total_amount], "must equal the subtotal minus the discount"
  end

  test "rejects a discount larger than the subtotal" do
    order = build_order(discount_amount: BigDecimal("11.00"), total_amount: BigDecimal("-1.00"))
    assert_not order.valid?
    assert_includes order.errors[:discount_amount], "cannot exceed the subtotal"
  end

  test "rejects negative amounts" do
    assert_not build_order(subtotal_amount: BigDecimal("-1"), discount_amount: 0, total_amount: BigDecimal("-1")).valid?
    assert_not build_order(discount_amount: BigDecimal("-1"), total_amount: BigDecimal("11.00")).valid?
  end

  test "a promo code used by an order cannot be deleted" do
    code = promo_codes(:ten_percent)
    build_order(promo_code: code).save!
    assert_raises(ActiveRecord::DeleteRestrictionError) { code.destroy }
  end

  test "database constraints reject inconsistent amounts that bypass validations" do
    id = orders(:one).id
    assert_raises(ActiveRecord::StatementInvalid) { Order.where(id: id).update_all(discount_amount: 20) }
    assert_raises(ActiveRecord::StatementInvalid) { Order.where(id: id).update_all(total_amount: -1) }
  end
end
