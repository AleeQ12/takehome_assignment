class Order < ApplicationRecord
  belongs_to :user
  belongs_to :promo_code, optional: true
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  validates :subtotal_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :discount_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: %w[pending completed cancelled] }
  validate :amounts_are_consistent

  private

  def amounts_are_consistent
    return if [subtotal_amount, discount_amount, total_amount].any?(&:nil?)

    errors.add(:discount_amount, "cannot exceed the subtotal") if discount_amount > subtotal_amount
    unless total_amount == subtotal_amount - discount_amount
      errors.add(:total_amount, "must equal the subtotal minus the discount")
    end
  end
end
