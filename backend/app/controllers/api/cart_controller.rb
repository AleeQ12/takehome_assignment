class Api::CartController < ApplicationController
  def show
    render json: cart_payload(current_user.cart), status: :ok
  end

  # PUT /api/cart/promo_code { "code": "..." }
  # Sets or replaces the cart's single promo code. A failed attempt leaves the cart unchanged.
  def apply_promo_code
    cart = current_user.cart
    entered = params[:code]

    return render_promo_code_error(:blank) if PromoCode.normalize(entered).empty?

    promo_code = PromoCode.find_by_normalized_code(entered)
    return render_promo_code_error(:not_found) unless promo_code

    reason = promo_code.unusable_reason
    return render_promo_code_error(reason) if reason

    cart.update!(promo_code: promo_code)
    render json: cart_payload(cart), status: :ok
  end

  # DELETE /api/cart/promo_code (idempotent)
  def remove_promo_code
    cart = current_user.cart
    cart.update!(promo_code: nil) if cart.promo_code_id
    render json: cart_payload(cart), status: :ok
  end

  def add_item
    cart = current_user.cart
    product = Product.find(params[:product_id])
    quantity = params[:quantity] || 1

    cart_item = cart.cart_items.find_or_initialize_by(product: product)
    # A new cart item starts at the column default (1), so only add to an existing quantity.
    existing_quantity = cart_item.new_record? ? 0 : cart_item.quantity
    cart_item.quantity = existing_quantity + quantity.to_i

    if cart_item.save
      render json: { message: 'Item added to cart', cart_item: cart_item }, status: :ok
    else
      render json: { errors: cart_item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product not found' }, status: :not_found
  end

  def update_item
    cart_item = current_user.cart.cart_items.find(params[:id])
    if cart_item.update(quantity: params[:quantity])
      render json: { message: 'Cart item updated', cart_item: cart_item }, status: :ok
    else
      render json: { errors: cart_item.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Cart item not found' }, status: :not_found
  end

  def remove_item
    cart_item = current_user.cart.cart_items.find(params[:id])
    cart_item.destroy
    render json: { message: 'Item removed from cart' }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Cart item not found' }, status: :not_found
  end

  private

  # Shared cart response for show, apply and remove. subtotal/discount/total are a live
  # preview computed from current prices; persisted order amounts live on the order.
  def cart_payload(cart)
    now = Time.current
    pricing = cart.price_breakdown(now)

    {
      id: cart.id,
      items: cart.cart_items.includes(:product).map do |item|
        {
          id: item.id,
          product: {
            id: item.product.id,
            name: item.product.name,
            description: item.product.description,
            price: item.product.price,
            image_url: item.product.image_url,
            stock_quantity: item.product.stock_quantity
          },
          quantity: item.quantity,
          subtotal: item.subtotal
        }
      end,
      subtotal: pricing[:subtotal],
      discount: pricing[:discount],
      total: pricing[:total],
      promo_code: promo_code_payload(cart.promo_code, now)
    }
  end

  def promo_code_payload(promo_code, now)
    return nil unless promo_code

    reason = promo_code.unusable_reason(now)
    {
      code: promo_code.code,
      discount_type: promo_code.discount_type,
      discount_value: promo_code.discount_value,
      valid: reason.nil?,
      error_code: reason&.to_s,
      message: reason && PromoCode.error_message(reason)
    }
  end

  def render_promo_code_error(reason)
    render json: { error: PromoCode.error_message(reason), error_code: reason.to_s },
           status: :unprocessable_entity
  end
end
