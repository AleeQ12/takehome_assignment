class AddPricingToOrders < ActiveRecord::Migration[7.0]
  def change
    # Added as nullable first so existing rows stay valid until they are backfilled.
    add_column :orders, :subtotal_amount, :decimal, precision: 10, scale: 2
    add_column :orders, :discount_amount, :decimal, precision: 10, scale: 2, null: false, default: 0
    add_reference :orders, :promo_code, null: true, index: true, foreign_key: true

    # Existing orders had no discount, so their subtotal equals the amount paid.
    reversible do |dir|
      dir.up { execute "UPDATE orders SET subtotal_amount = total_amount" }
    end

    change_column_null :orders, :subtotal_amount, false

    # Check constraints go last: SQLite rebuilds the table for the changes above.
    add_check_constraint :orders, "subtotal_amount >= 0", name: "orders_subtotal_nonnegative"
    add_check_constraint :orders, "discount_amount >= 0 AND discount_amount <= subtotal_amount", name: "orders_discount_range"
    add_check_constraint :orders, "total_amount >= 0", name: "orders_total_nonnegative"
  end
end
