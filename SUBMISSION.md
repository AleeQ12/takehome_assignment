# Submission — Naveed Tariq — Backend

**Video walkthrough:** _TODO: add unlisted link_

**Time spent:** about **2 h 45 min** of hands-on work on 9 October 2026, measured from the AI session log:

- **Active window:** from the baseline-repair prompt at 13:04 to the final documentation commit at 15:48 (2 h 44 min).
- **Discovery:** the initial repository-discovery prompt ran the night before (01:32, about 2 minutes of AI time), followed by a break. My own reading of the codebase between sessions was not logged.
- **Claude's share:** about **29 minutes of processing across 29 prompts, averaging about 1 minute per prompt**. The rest of the window was my review of designs and diffs, running Rails commands and tests, iOS simulator testing, and commits.

Per-phase timings are in `PROMPTS.md` (Step 5, "Time log").

**AI tools used:** Claude in the Claude desktop app (Cowork), with access to the local repository. Claude read and edited files and ran syntax checks, TypeScript and ESLint. It could not run Rails or Bundler (rubygems.org was blocked in its environment), so I ran every Rails command and test and pasted the output back. Details are in `PROMPTS.md`.

## What I built

Shoppers can apply one promo code to their cart and see the discount and new total before checkout. Invalid codes explain why they failed. Checkout re-checks the code and stores what was actually paid, and order history shows the stored amounts. Percentage and fixed discounts, expiry and early deactivation are supported.

| Commit | What |
|---|---|
| `cee9c09` | Baseline repair: fixed a syntax error in `OrdersController#index` that stopped orders and checkout from loading; fixed duplicate user fixtures; added orders integration tests |
| `43348c0` | Schema: `promo_codes` with check constraints; `carts.promo_code_id`; `orders.subtotal_amount`, `discount_amount` and `promo_code_id` (existing orders backfilled) |
| `8204515` | `PromoCode` model and BigDecimal cart pricing (discount rounded half-up, capped at the subtotal); order amount validations; seeded codes |
| `7860c25` | `PUT` / `DELETE /api/cart/promo_code`; shared cart payload with `subtotal` / `discount` / `total`; `{error, error_code}` 422 contract |
| `15fac2e` | Atomic checkout that re-checks the code; persisted order pricing; order history fields |
| `19f2381` | Mobile: promo-code input, Apply/Replace/Remove, inline errors, subtotal/discount/total breakdown |
| `0a98f4d` | Pre-existing bug: adding a new product stored one more than requested |

## How to run what I added

```bash
cd backend
bundle install
bin/rails db:migrate      # 3 new migrations; existing orders are backfilled
bin/rails db:seed         # WARNING: wipes existing data; creates users, products and promo codes
bin/rails test            # 67 runs, 303 assertions (see Testing)
bin/rails server -b 0.0.0.0
```

Mobile: no new dependencies or native changes. Start Metro and the app as described in the main README, sign in as `test@example.com` / `password123`, open the cart, and enter a code in the "Promo code" box at the top.

The mobile feature code is in `19f2381`. My local iOS setup changed `project.pbxproj`, `Info.plist` and `package-lock.json`, and created `Podfile.lock` and `MobileApp.xcworkspace`. These came from `pod install` and `npm install`, so I deliberately left them out of every commit.

API details (endpoints, payloads, error codes) are in `backend/README.md`.

## Promo codes to try

These are created by `bin/rails db:seed`.

| Code | Type | Expected result |
|---|---|---|
| `WELCOME10` | 10% off | Applies (seeded cart 118.94 → discount 11.89, total 107.05) |
| `SAVE5` | 5.00 off | Applies |
| `MAKEGOOD50` | 50.00 off | Applies; on a cart under 50.00 the discount is capped and the total is 0.00 |
| `EXPIRED20` | 20% off, expired | Rejected: "This promo code has expired." |
| `RETIRED15` | 15% off, deactivated | Rejected: "This promo code is no longer active." |

Codes are case-insensitive and surrounding spaces are ignored. Marketing can switch a code off early with `PromoCode.find_by!(code: "SAVE5").update!(active: false)`.

## Decisions and assumptions

- **The applied code is stored on the cart.** One nullable `carts.promo_code_id`, so a cart holds at most one code by construction. The server holds the state, so checkout needs no request body and the mobile checkout call is unchanged. Applying a new valid code replaces the current one; a failed apply leaves it alone.
- **The server decides every price.** The client sends only the code. Subtotal, discount and total are recalculated from current database prices on every cart request and again at checkout.
- **Money handling.** All money is BigDecimal: rounded half-up to cents once, on the discount, and capped at the subtotal, so `subtotal − discount = total` exactly and the total is never negative.
- **Free orders are allowed.** A code can bring the total to 0.00, for example a make-good code from support. This needed relaxing the existing `total_amount > 0` validation.
- **An invalid code blocks checkout.** If a code expires or is deactivated after being applied, checkout returns 422 with the reason and keeps the cart, instead of silently charging more than the shopper was shown.
- **Errors are specific:** `blank`, `not_found`, `inactive` or `expired`, each with a message for the shopper. This tells someone whether a code exists, which I accepted because the brief asks to explain failures.
- **Expiry** is an exact UTC instant (`expires_at`). Early deactivation is a boolean `active` flag.
- **Orders store their amounts.** `subtotal_amount`, `discount_amount` and `total_amount` (the amount paid) are written at checkout and never recalculated. The order links to the code with a foreign key; I added no code snapshot because the code can't be renamed (`attr_readonly`), and a code used by an order can't be deleted (restricted at the database).
- **Checkout is atomic.** One transaction with exception-raising writes. Expected failures (insufficient stock, other validation errors) return 422 after rollback; unexpected errors are not swallowed.
- **Database check constraints** back up the model validations: normalized code, discount type, value ranges, non-negative amounts, and discount ≤ subtotal.
- **Testing codes.** Seeded codes are how reviewers try codes. A marketing admin interface was out of scope.

## Testing

Final run, on the final code (`0a98f4d`; only documentation changed afterwards), Ruby 3.2.2 and Rails 7.0.10: `bin/rails test` gave **67 runs, 303 assertions, 0 failures, 0 errors** (parallel, 8 processes). A read-only check confirmed all five seeded codes exist and behave as listed above.

Baseline, before any promo work (`cee9c09`, *Fix orders endpoint and add integration coverage*): `bin/rails test` gave 3 runs, 15 assertions, 0 failures, and iOS checkout showed "Order placed successfully!".

- **Model tests:** normalization and lookup, validations, database constraints, validity at the exact expiry instant, rounding (including 0.005 → 0.01), capping, zero subtotal, BigDecimal-only inputs, cart breakdown, order amount consistency, and deletion rules.
- **Cart API tests:** response shape, percentage, fixed and capped discounts, every error code, replace, failed replacement keeping the current code, remove, codes invalidated after applying, authentication, and per-user isolation.
- **Checkout and history tests:**
  - persisted amounts with and without a code, and checkout through the cart API;
  - a zero total, and an empty cart;
  - codes deactivated or expired before checkout;
  - rollback after partial writes, and unexpected errors propagating with rollback;
  - history keeping stored values after code and price changes.
- **Add-to-cart tests:** regression tests for the off-by-one bug; all four fail on the old code.
- **Manual checks:**
  - curl against seeded data (apply, reject expired, remove, promo checkout and history);
  - an iOS simulator walkthrough of apply, invalid codes, replace, remove, a quantity change and checkout;
  - `tsc --noEmit` clean.

## Pre-existing issues found

- **Fixed:**
  - the `OrdersController#index` syntax error;
  - duplicate fixture emails;
  - float cart pricing;
  - non-atomic checkout, where an oversold item silently skipped its stock update while the order still completed;
  - the add-to-cart off-by-one.
- **Not fixed (documented):**
  - The seeded sample order's `total_amount` (89.97) does not match its items (98.98).
  - The mobile `AuthContext` checks a stored token against a public endpoint and sets a placeholder user.
  - Three ESLint errors existed before this work in the files I touched.

## What I didn't get to, and what I'd do next

- **Concurrency.** SQLite ignores row locks, so two simultaneous checkouts of the same cart, or of the last unit in stock, are not fully serialized. Next: a guarded stock decrement (`UPDATE … WHERE stock_quantity >= ?`), an idempotency key on checkout, and row locks on Postgres.
- **Price changes between preview and checkout.** Checkout uses current prices, as it did before. An optional `expected_total` could reject checkout if the amount changed.
- **Marketing tools:** an admin API or UI to create, deactivate and report on codes.
- **Not in the brief:** usage limits (total or per customer), first-order-only codes, start dates and minimum spend.
- **Partial refunds:** the discount is stored per order, not split across line items.
- **Mobile polish:** a discount line in the order-history UI, the paid amount in the success alert, and mobile tests (Jest).
- **Existing bugs:** fix the seed data mismatch, the auth placeholder user and the pre-existing ESLint errors.

See `PROMPTS.md` for the full AI-assisted development log: every prompt, what the AI got wrong, and where we changed direction.
