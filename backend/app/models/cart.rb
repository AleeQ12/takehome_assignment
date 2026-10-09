class Cart < ApplicationRecord
  belongs_to :user
  belongs_to :promo_code, optional: true
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  # Undiscounted sum of current product prices times quantities.
  def subtotal
    cart_items.includes(:product).to_a.sum(PromoCode::ZERO) { |item| item.subtotal }
  end

  # Server-side price breakdown. A code that is no longer usable contributes no discount.
  def price_breakdown(at = Time.current)
    subtotal_amount = subtotal
    discount = promo_code&.usable?(at) ? promo_code.discount_for(subtotal_amount) : PromoCode::ZERO
    { subtotal: subtotal_amount, discount: discount, total: subtotal_amount - discount }
  end

  def discount_amount
    price_breakdown[:discount]
  end

  # Amount payable after any usable promo code.
  def total
    price_breakdown[:total]
  end
end
