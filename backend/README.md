# Rails API Backend

Ruby on Rails API backend for the shopping cart application.

## Setup

1. **Install dependencies**:
   ```bash
   bundle install
   ```

2. **Set up the database**:
   ```bash
   rails db:migrate
   rails db:seed
   ```

3. **Start the server**:
   ```bash
   rails server
   ```

The API will be available at `http://localhost:3000`

## Database

- **Database**: SQLite (development)
- **Migrations**: Run with `rails db:migrate`
- **Seeds**: Run with `rails db:seed` to populate sample data. Seeding deletes all existing data first, including promo codes.
- **Tests**: Run with `bin/rails test`. Minitest model and integration tests cover promo codes, cart pricing, checkout and adding items to the cart.

## API Documentation

### Authentication

All endpoints except `/api/auth/*` and `/api/products` require authentication via JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

### Endpoints

#### Authentication

- `POST /api/auth/login`
  - Body: `{ "email": "user@example.com", "password": "password123" }`
  - Returns: `{ "token": "...", "user": { "id": 1, "email": "..." } }`

- `POST /api/auth/signup`
  - Body: `{ "user": { "email": "user@example.com", "password": "password123", "password_confirmation": "password123" } }`
  - Returns: `{ "token": "...", "user": { "id": 1, "email": "..." } }`

#### Products

- `GET /api/products` - List all products
- `GET /api/products/:id` - Get product details

#### Cart (Authenticated)

- `GET /api/cart` - Get user's cart with items and a price breakdown
- `POST /api/cart/items` - Add item to cart
  - Body: `{ "product_id": 1, "quantity": 2 }`
- `PATCH /api/cart/items/:id` - Update cart item quantity
  - Body: `{ "quantity": 3 }`
- `DELETE /api/cart/items/:id` - Remove item from cart
- `PUT /api/cart/promo_code` - Apply a promo code, replacing any code already applied
  - Body: `{ "code": "welcome10" }` (surrounding spaces are ignored and case does not matter)
  - Returns the full cart payload (below)
  - A failed attempt returns `422` and leaves the currently applied code unchanged
- `DELETE /api/cart/promo_code` - Remove the applied code. Safe to call when no code is applied; returns the cart payload.

`GET /api/cart` and both promo-code endpoints return the same payload. `subtotal`, `discount` and `total` are a live preview, recalculated from current prices on every request:

```json
{
  "id": 1,
  "items": [{ "id": 3, "product": { "...": "..." }, "quantity": 2, "subtotal": "49.98" }],
  "subtotal": "118.94",
  "discount": "11.89",
  "total": "107.05",
  "promo_code": {
    "code": "WELCOME10", "discount_type": "percentage", "discount_value": "10.0",
    "valid": true, "error_code": null, "message": null
  }
}
```

`promo_code` is `null` when no code is applied. If an applied code later expires or is deactivated, it stays on the cart with `"valid": false`, an `error_code` and a `message`, and no discount is given.

Money values are decimal strings. The discount is rounded half-up to cents and never exceeds the subtotal, so `total` is never negative.

#### Promo-code errors

Validation failures return `422` with `{ "error": "<message for the shopper>", "error_code": "<code>" }`:

| `error_code` | When |
|---|---|
| `blank` | No code was entered |
| `not_found` | No code matches |
| `inactive` | The code has been deactivated |
| `expired` | The code's `expires_at` has passed |

#### Orders (Authenticated)

- `GET /api/orders` - List user's orders
- `POST /api/orders` - Create order from cart (no body)

Order responses include `subtotal_amount`, `discount_amount`, `total_amount` (the amount paid) and `promo_code` (the code string or `null`). These values are stored at checkout and never recalculated, so order history stays accurate even if a code later expires or prices change.

Checkout:
- checks the applied promo code again. If it has expired or been deactivated, checkout returns `422` with `error_code` `expired` or `inactive`, and the cart and its code are left as they are;
- creates the order and its items, updates stock, and clears the cart and its code in a single transaction;
- returns `422` with `error_code` `insufficient_stock` or `checkout_failed` for expected validation failures, after rolling everything back. Unexpected errors are not caught.

A discount that covers the whole subtotal produces a `0.00` order.

## Models

- **User**: Email, password (bcrypt)
- **Product**: Name, description, price, image_url, stock_quantity
- **Cart**: Belongs to user (one per user); optional applied promo code
- **CartItem**: Cart, product, quantity
- **Order**: User, subtotal_amount, discount_amount, total_amount (amount paid), status, optional promo code
- **PromoCode**:
  - `code`: unique, stored uppercase and trimmed, cannot be changed after creation;
  - `discount_type`: `percentage` or `fixed`;
  - `discount_value`: positive; percentages at most 100;
  - `active`: set to false to switch a code off early;
  - `expires_at`: optional; the code is expired from this exact instant.

  Database check constraints mirror the validations. A code used by an order cannot be deleted; deactivate it instead.
- **OrderItem**: Order, product, quantity, price

## Configuration

- **CORS**: Configured in `config/initializers/cors.rb`
- **JWT Secret**: Uses Rails secret key base (set in production)
- **Password**: Minimum 6 characters

## Promo codes to try

`rails db:seed` creates these codes. It wipes existing data first.

| Code | Type | Expected result |
|---|---|---|
| `WELCOME10` | 10% off | Applies; with the seeded cart (118.94) the discount is 11.89 and the total 107.05 |
| `SAVE5` | 5.00 off | Applies |
| `MAKEGOOD50` | 50.00 off | Applies; on a cart under 50.00 the discount is capped and the total is 0.00 |
| `EXPIRED20` | 20% off, expired | Rejected with `expired` |
| `RETIRED15` | 15% off, deactivated | Rejected with `inactive` |

To switch a code off early from the console:

```bash
bin/rails runner 'PromoCode.find_by!(code: "SAVE5").update!(active: false)'
```
