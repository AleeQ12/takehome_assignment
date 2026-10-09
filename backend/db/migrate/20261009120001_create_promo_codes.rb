class CreatePromoCodes < ActiveRecord::Migration[7.0]
  def change
    create_table :promo_codes do |t|
      t.string :code, null: false
      t.string :discount_type, null: false
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.boolean :active, null: false, default: true
      t.datetime :expires_at

      t.timestamps

      t.index :code, unique: true
      t.check_constraint "code = UPPER(TRIM(code)) AND code <> ''", name: "promo_codes_code_normalized"
      t.check_constraint "discount_type IN ('percentage', 'fixed')", name: "promo_codes_discount_type"
      t.check_constraint "discount_value > 0", name: "promo_codes_discount_value_positive"
      t.check_constraint "discount_type <> 'percentage' OR discount_value <= 100", name: "promo_codes_percentage_max"
    end
  end
end
