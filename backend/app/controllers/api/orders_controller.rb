class Api::OrdersController < ApplicationController
  def index
    orders = current_user.orders
                         .includes(:promo_code, order_items: :product)
                         .order(created_at: :desc)
    payload = orders.map do |order|
      order_payload(order).merge(
        items: order.order_items.map do |item|
          {
            product_name: item.product.name,
            quantity: item.quantity,
            price: item.price,
            subtotal: item.subtotal
          }
        end
      )
    end
    render json: payload, status: :ok
  end

  def create
    cart = current_user.cart
    if cart.cart_items.empty?
      render json: { error: 'Cart is empty' }, status: :unprocessable_entity
      return
    end

    # Re-check the applied code before writing anything. An invalid code blocks checkout
    # (and stays on the cart) rather than silently charging a different amount.
    now = Time.current
    promo_code = cart.promo_code
    reason = promo_code&.unusable_reason(now)
    if reason
      render json: { error: "#{PromoCode.error_message(reason)} Remove it to check out.", error_code: reason.to_s },
             status: :unprocessable_entity
      return
    end

    order = nil
    ActiveRecord::Base.transaction do
      items = cart.cart_items.includes(:product).to_a
      pricing = cart.price_breakdown(now)

      order = Order.create!(
        user: current_user,
        promo_code: promo_code,
        subtotal_amount: pricing[:subtotal],
        discount_amount: pricing[:discount],
        total_amount: pricing[:total],
        status: 'pending'
      )

      items.each do |item|
        product = item.product
        OrderItem.create!(order: order, product: product, quantity: item.quantity, price: product.price)
        # Raises RecordInvalid if stock would go negative (Product validates stock_quantity >= 0).
        product.update!(stock_quantity: product.stock_quantity - item.quantity)
      end

      items.each(&:destroy!)
      cart.update!(promo_code: nil)
    end

    render json: order_payload(order), status: :created
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    # Expected validation failures only; the transaction has already rolled back.
    # Any other exception propagates unchanged.
    render_checkout_failure(e.record)
  end

  private

  # subtotal_amount/discount_amount/total_amount are persisted at checkout and never
  # recalculated; total_amount is the amount paid.
  def order_payload(order)
    {
      id: order.id,
      subtotal_amount: order.subtotal_amount,
      discount_amount: order.discount_amount,
      total_amount: order.total_amount,
      promo_code: order.promo_code&.code,
      status: order.status,
      created_at: order.created_at
    }
  end

  def render_checkout_failure(record)
    if record.is_a?(Product)
      render json: { error: "Not enough stock for #{record.name}.", error_code: 'insufficient_stock' },
             status: :unprocessable_entity
    else
      message = record.errors.full_messages.to_sentence.presence || 'Checkout could not be completed.'
      render json: { error: message, error_code: 'checkout_failed' }, status: :unprocessable_entity
    end
  end
end
