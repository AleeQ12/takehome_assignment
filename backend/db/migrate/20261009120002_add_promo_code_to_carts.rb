class AddPromoCodeToCarts < ActiveRecord::Migration[7.0]
  def change
    add_reference :carts, :promo_code, null: true, index: true, foreign_key: { on_delete: :nullify }
  end
end
