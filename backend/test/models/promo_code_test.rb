require "test_helper"

class PromoCodeTest < ActiveSupport::TestCase
  def build_code(attrs = {})
    PromoCode.new({ code: "NEWCODE", discount_type: "fixed", discount_value: 5 }.merge(attrs))
  end

  # Normalization and lookup

  test "normalizes the code by trimming whitespace and upcasing" do
    code = build_code(code: "  welcome10 ")
    assert code.save
    assert_equal "WELCOME10", code.reload.code
  end

  test "rejects a duplicate code that differs only in case or whitespace" do
    duplicate = build_code(code: " tenoff ")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "rejects a blank code" do
    assert_not build_code(code: "   ").valid?
  end

  test "finds a code using the same normalization" do
    assert_equal promo_codes(:ten_percent), PromoCode.find_by_normalized_code("  tenoff ")
    assert_nil PromoCode.find_by_normalized_code("   ")
    assert_nil PromoCode.find_by_normalized_code("NOPE")
  end

  test "code cannot be changed after creation" do
    code = promo_codes(:ten_percent)
    code.update(code: "RENAMED")
    assert_equal "TENOFF", code.reload.code
  end

  test "has a shopper-facing message for every error code" do
    %i[blank not_found inactive expired].each do |reason|
      assert_predicate PromoCode.error_message(reason), :present?
    end
    assert_raises(KeyError) { PromoCode.error_message(:unknown) }
  end

  # Discount type and value validations

  test "requires a supported discount type" do
    assert_not build_code(discount_type: "bogus").valid?
    assert build_code(discount_type: "percentage", discount_value: 10).valid?
  end

  test "requires a positive discount value" do
    assert_not build_code(discount_value: 0).valid?
    assert_not build_code(discount_value: -1).valid?
    assert_not build_code(discount_value: nil).valid?
  end

  test "caps percentage discounts at 100 but not fixed discounts" do
    assert_not build_code(discount_type: "percentage", discount_value: 100.01).valid?
    assert build_code(discount_type: "percentage", discount_value: 100).valid?
    assert build_code(discount_type: "fixed", discount_value: 150).valid?
  end

  test "database constraints reject values that bypass model validations" do
    id = promo_codes(:ten_percent).id
    assert_raises(ActiveRecord::StatementInvalid) { PromoCode.where(id: id).update_all(discount_value: 0) }
    assert_raises(ActiveRecord::StatementInvalid) { PromoCode.where(id: id).update_all(discount_value: 101) }
    assert_raises(ActiveRecord::StatementInvalid) { PromoCode.where(id: id).update_all(discount_type: "bogus") }
    assert_raises(ActiveRecord::StatementInvalid) { PromoCode.where(id: id).update_all(code: "lower") }
  end

  # Validity

  test "an active code without an expiry is usable" do
    assert_nil promo_codes(:ten_percent).unusable_reason
    assert promo_codes(:ten_percent).usable?
  end

  test "an active code expiring in the future is usable" do
    assert_nil promo_codes(:future).unusable_reason
  end

  test "a deactivated code is inactive" do
    assert_equal :inactive, promo_codes(:inactive).unusable_reason
    assert_not promo_codes(:inactive).usable?
  end

  test "a code past its expiry is expired" do
    assert_equal :expired, promo_codes(:expired).unusable_reason
  end

  test "a code is expired from the exact expiry instant" do
    code = promo_codes(:future)
    travel_to(code.expires_at - 1.second) { assert_nil code.unusable_reason }
    travel_to(code.expires_at) { assert_equal :expired, code.unusable_reason }
  end

  # Discount calculation

  test "percentage discounts round half up to cents" do
    ten = promo_codes(:ten_percent)
    assert_equal BigDecimal("1.00"), ten.discount_for(BigDecimal("9.99"))   # 0.999
    assert_equal BigDecimal("0.01"), ten.discount_for(BigDecimal("0.05"))   # 0.005
    assert_equal BigDecimal("5.00"), build_code(discount_type: "percentage", discount_value: 15)
                                       .discount_for(BigDecimal("33.33"))   # 4.9995
  end

  test "fixed discounts apply their amount" do
    assert_equal BigDecimal("5.00"), promo_codes(:five_off).discount_for(BigDecimal("9.99"))
  end

  test "discounts are capped at the subtotal" do
    assert_equal BigDecimal("9.99"), promo_codes(:big_fixed).discount_for(BigDecimal("9.99"))
    assert_equal BigDecimal("118.94"), promo_codes(:full).discount_for(BigDecimal("118.94"))
  end

  test "a zero subtotal gets a zero discount" do
    assert_equal BigDecimal("0"), promo_codes(:five_off).discount_for(BigDecimal("0"))
    assert_equal BigDecimal("0"), promo_codes(:ten_percent).discount_for(BigDecimal("0"))
  end

  test "discount calculations use BigDecimal only" do
    assert_kind_of BigDecimal, promo_codes(:ten_percent).discount_for(BigDecimal("9.99"))
    assert_kind_of BigDecimal, promo_codes(:five_off).discount_for(BigDecimal("9.99"))
    assert_raises(ArgumentError) { promo_codes(:ten_percent).discount_for(9.99) }
  end
end
