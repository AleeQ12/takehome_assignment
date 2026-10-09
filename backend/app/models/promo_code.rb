class PromoCode < ApplicationRecord
  DISCOUNT_TYPES = %w[percentage fixed].freeze
  ZERO = BigDecimal("0")
  HUNDRED = BigDecimal("100")

  # Shopper-facing messages for each reason a code cannot be applied or used.
  ERROR_MESSAGES = {
    blank: "Please enter a promo code.",
    not_found: "We couldn't find that promo code.",
    inactive: "This promo code is no longer active.",
    expired: "This promo code has expired."
  }.freeze

  has_many :carts, dependent: :nullify
  has_many :orders, dependent: :restrict_with_exception

  # Orders show the code label through this association, so it must not change once created.
  attr_readonly :code

  before_validation :normalize_code

  validates :code, presence: true, uniqueness: true
  validates :discount_type, inclusion: { in: DISCOUNT_TYPES }
  validates :discount_value, presence: true, numericality: { greater_than: 0 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?
  validates :active, inclusion: { in: [true, false] }

  def self.normalize(code)
    code.to_s.strip.upcase
  end

  # Looks up a shopper-entered code using the same normalization applied on save.
  def self.find_by_normalized_code(code)
    normalized = normalize(code)
    normalized.empty? ? nil : find_by(code: normalized)
  end

  def self.error_message(reason)
    ERROR_MESSAGES.fetch(reason.to_sym)
  end

  def percentage?
    discount_type == "percentage"
  end

  def fixed?
    discount_type == "fixed"
  end

  # nil when the code can be used at the given time, otherwise :inactive or :expired.
  def unusable_reason(at = Time.current)
    return :inactive unless active?
    return :expired if expires_at.present? && expires_at <= at

    nil
  end

  def usable?(at = Time.current)
    unusable_reason(at).nil?
  end

  # Discount for a subtotal: rounded half-up to cents and never more than the subtotal.
  def discount_for(subtotal)
    raise ArgumentError, "subtotal must be a BigDecimal" unless subtotal.is_a?(BigDecimal)
    return ZERO unless subtotal.positive?

    raw = percentage? ? subtotal * discount_value / HUNDRED : discount_value
    [raw.round(2, BigDecimal::ROUND_HALF_UP), subtotal].min
  end

  private

  def normalize_code
    self.code = self.class.normalize(code) unless code.nil?
  end
end
