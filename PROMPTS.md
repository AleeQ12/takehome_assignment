# AI-Assisted Development Log

## Project: Promo Codes for a Shopping App

**Assignment:** Add promo-code functionality to an existing Rails API and React Native shopping application.

**AI tool:** Claude, in the Claude desktop app (Cowork), with read and write access to my local repository. Earlier drafts of this log said "Claude Code"; that was inaccurate and has been corrected below, though quoted prompts are left as written.

**Division of work:**
- Claude inspected the code, proposed designs, wrote the changes and ran the checks available to it: `ruby -c` / `ruby -wc`, `tsc --noEmit`, ESLint and `git diff --check`.
- Its environment could not reach rubygems.org, so it could not install gems or run Rails. **I ran every Rails command, migration, seed and test, and every manual curl and iOS check, then pasted the output back.**
- I reviewed each diff and made every commit myself, after my approval.

**Development approach:** Repository discovery, baseline verification, incremental implementation, automated testing, and human review.

**Timebox:** Approximately 2–3 hours of hands-on work.

## Summary for reviewers

**Where the AI got something wrong or needed correcting:**
- **Step 2 (environment):** Claude could not run the Rails test suite; Ruby 3.2.2 and gems were unavailable to it. The baseline fix was verified only by my local runs.
- **Increment 1 (plan):** the agreed plan put promo-code seeds in the schema increment, before the `PromoCode` model existed. Claude noticed this before writing them, and I chose to defer them to Increment 2.
- **Increment 1 (missed consequence):** the new NOT NULL `orders.subtotal_amount` broke checkout, and the first test run failed. Claude offered three options; I chose a one-line fix that keeps the commit green.
- **Increment 2:** changing `Cart#total` to the discounted total made the Increment 1 compatibility line semantically wrong (it read the subtotal from `total`). Claude caught this itself and switched it to `cart.subtotal`.
- **Bug fix:** Claude predicted 3 of 4 regression tests would fail on the old code; all 4 did, because the bug affected every flow that starts by adding a new product.
- **Missed until manual testing:** the add-to-cart off-by-one was pre-existing and was only found during my iOS walkthrough, not by the AI's inspection.

**Where we changed direction:**
- **Where the applied code lives:** it is stored on the cart rather than passed as request parameters, so the server holds it and the checkout request stays unchanged.
- **Row locking:** the initial design used `lock!` at checkout. It was dropped because SQLite ignores row locks, and documented as a known limitation instead.
- **Error handling:** at my request, checkout rescues only expected validation errors and lets unexpected exceptions propagate.
- **Safe database operations:** at my request, the development database was backed up before migrations, and rollback checks ran only against the disposable test database.
- **Seed timing:** the promo-code seeds were deferred to Increment 2, and a compatibility line kept Increment 1 green.
- **Pre-existing bug:** the add-to-cart fix was committed separately from the mobile increment.
- **Mobile layout:** the promo input went at the top of the cart list rather than in the footer, so the iOS keyboard cannot cover it.
- **Timebox:** the order-history discount line in the mobile UI was left optional.

---

# Step 1 — Repository Discovery and Baseline Assessment

## Objective

Understand the existing Rails API and React Native application before making changes. Identify the current cart and checkout flows, data models, testing conventions, and risks relevant to adding promo codes.

The goal was to understand the existing implementation before asking AI to modify application code.

## Prompt used

The following prompt was used with Claude. It is lightly reformatted (bullet capitalization and wording); the substance is unchanged.

> You are working with me on a backend-focused take-home assignment.
>
> Do NOT modify any files yet.
>
> First inspect the existing repository, with particular attention to:
>
> - Backend Rails application structure
> - Models and associations
> - Database schema and migrations
> - Existing cart implementation
> - Existing order and checkout implementation
> - Authentication and current-user handling
> - Existing API controllers, routes, and serializers
> - Pricing and total calculation logic
> - Existing tests and test conventions
> - Seed data
> - React Native cart and checkout implementation
> - README instructions
>
> I am adding promo codes to an existing shopping application.
>
> The product brief requires:
>
> - Signed-in shoppers can enter a promo code on their cart.
> - Valid codes show a discount and new total before checkout.
> - Invalid codes explain why they failed.
> - Checkout persists the actual amount paid.
> - Order history reflects the discounted amount.
> - Percentage and fixed discounts are supported.
> - Promo codes can expire or be deactivated early.
> - One promo code is allowed per order.
>
> Do not implement anything.
>
> Instead give me:
>
> 1. Existing architecture
> 2. Relevant models and relationships
> 3. Existing pricing and checkout flow
> 4. Existing API endpoints
> 5. Existing frontend flow relevant to cart and checkout
> 6. Existing test strategy
> 7. Files that would likely need changing
> 8. Potential architectural risks
> 9. Important ambiguities in the product brief
> 10. A minimal implementation plan suitable for a 2–3 hour backend-focused take-home
>
> Be conservative. Prefer extending existing patterns over introducing new abstractions.
>
> Do not invent details about the application that you have not verified from the code.

## Scope and constraints

- Inspect the existing implementation before making changes.
- Prefer extending established application patterns over introducing unnecessary abstractions.
- Identify existing behavior separately from assumptions.
- Do not implement the promo-code feature during discovery.
- Keep the implementation focused on the assignment and its timebox.

## Findings from AI-assisted inspection

The initial repository inspection identified the following characteristics and potential issues:

- The application uses a Rails API with SQLite.
- API responses are constructed directly in controllers rather than through a dedicated serializer layer.
- Existing cart pricing uses floating-point arithmetic.
- The existing checkout flow does not wrap the entire order-creation process in one database transaction.
- Orders do not persist separate subtotal and discount amounts.
- Promo-code functionality does not yet exist.
- The orders controller contains a syntax error affecting the orders endpoint.
- Backend test coverage is minimal.
- The mobile cart may display stale totals after quantity changes.

These findings were reviewed against the source code. Runtime and test-related claims were subsequently checked where possible rather than being treated as verified solely from static analysis.

## Baseline verification — 9 October 2026

### Environment and application startup

- Ruby version: `3.2.2`
- Rails version: `7.0.10`
- Rails server: successfully started in development.
- iOS setup commands executed:
  - `bundle install`
  - `bundle exec pod install`
  - `npx react-native run-ios`

The application was launched locally, and the mobile app successfully sent requests to the Rails API.

### Initial checkout failure

When placing an order through the mobile app, checkout failed with an error dialog.

The Rails server log identified the following error:

```text
SyntaxError:
app/controllers/api/orders_controller.rb:19:
unexpected ',', expecting `end'
```

The failing expression was in `Api::OrdersController#index`:

```ruby
render json: orders.map do |order|
  # ...
end, status: :ok
```

The `do...end` block binds incorrectly in this expression, leaving the trailing comma invalid in this context. Ruby cannot parse the controller, preventing the endpoint from loading correctly.

### Initial testing status

The initial inspection identified a need to establish a reliable test baseline. The controller syntax error was reproduced through the running application before it was fixed.

## Human review

I inspected the repository and reviewed Claude's architectural findings. Most of the observations matched my own assessment of the codebase.

I decided to validate the existing application and fix the confirmed checkout blocker before implementing promo codes. This provides a more reliable baseline for identifying regressions introduced by the new feature.

## Decisions and next steps

1. Establish a working local environment.
2. Reproduce and document the existing checkout failure.
3. Fix the confirmed syntax error separately from the feature implementation.
4. Add focused regression coverage for the existing order endpoints.
5. Verify the backend behavior before designing the promo-code implementation.

## Reflection

Repository discovery helped identify existing constraints before implementation. In particular, understanding the current checkout flow and pricing model is important because promo codes affect both the amount displayed to the customer and the amount persisted when an order is created.

---

# Step 2 — Baseline Repair and Verification

## Objective

Repair the existing orders-controller syntax error and establish regression coverage for the current orders API before introducing new functionality.

The scope was deliberately limited to the baseline so that the promo-code feature would remain a separate change.

## AI-assisted task

Claude was asked to inspect the affected controller, correct the syntax error while preserving the existing API response structure, inspect test fixtures, add focused integration tests, and report the changes and verification commands.

The implementation was restricted to the existing orders endpoint and its supporting tests. Promo-code functionality and unrelated refactoring were explicitly excluded.

## Changes made

### 1. Fixed the orders-controller syntax error

File:

`backend/app/controllers/api/orders_controller.rb`

The original code passed a `map` block directly inside the `render` call. The correction builds the response payload first and then renders it:

```ruby
payload = orders.map do |order|
  # Existing order response structure
end

render json: payload, status: :ok
```

This preserves the existing response structure while correcting the syntax error.

### 2. Corrected duplicate user fixture emails

File:

`backend/test/fixtures/users.yml`

Both test users previously used the placeholder email `MyString`. They were changed to distinct addresses:

- `one@example.com`
- `two@example.com`

This avoids conflicting fixture values when the unique email constraint is enforced.

### 3. Added integration tests for the orders API

File:

`backend/test/integration/orders_test.rb`

Three integration tests were added.

**Test 1: Authenticated order listing**

Verifies that:

- The endpoint returns HTTP 200.
- The current user's order is returned.
- The response contains the expected order fields.
- The order item response contains the expected fields.
- The order total is serialized as expected.

**Test 2: Authentication is required**

Verifies that a request to `GET /api/orders` without an authentication token returns HTTP 401.

**Test 3: Order creation**

Verifies that:

- An order can be created from the current user's cart.
- The endpoint returns HTTP 201.
- The created order has the expected response fields and status.
- An order item is created.
- The cart is emptied after successful checkout.

## Verification results

The following commands were executed locally from the backend directory.

| Check | Result |
|---|---|
| `ruby -v` | Ruby 3.2.2 |
| `rails server -b 0.0.0.0` | Server starts successfully |
| `ruby -c app/controllers/api/orders_controller.rb` | `Syntax OK` |
| `bundle exec rails test` | 3 runs, 15 assertions, 0 failures, 0 errors, 0 skips |
| `bin/rails test test/integration/orders_test.rb -v` | 3 runs, 15 assertions, 0 failures, 0 errors, 0 skips |
| `git diff --check` | No whitespace errors reported |


## Integration-test observations

The order-creation integration test successfully exercised the API request and verified order creation, order-item creation, product-stock updates, and cart clearing.

The request log also showed that order creation and its associated operations use multiple separate database transactions. This is a potential consistency risk if a later operation fails after earlier changes have committed.

I recorded this as an area for consideration during the feature design rather than expanding the scope of the baseline repair.

## Human review

I reviewed the controller diff and the new integration tests.

The controller change is small and focused. It preserves the existing response structure while fixing the syntax error.

The tests provide initial regression coverage for the existing orders API and checkout behavior. They do not yet cover transaction rollback, stock consistency under failure, or the new promo-code requirements.

I also retested checkout through the iOS simulator. The app displayed **“Order placed successfully!”**, confirming that the original checkout error was resolved end to end.

## Known limitations and outstanding verification

- The working tree contains additional iOS setup changes that must be reviewed separately and excluded from the baseline-fix commit unless required.
- The current checkout flow has potential transaction-integrity concerns.
- Promo-code functionality has not yet been implemented.

## Engineering decision

Keep the baseline repair separate from the promo-code feature.

This makes the commit history easier to review, establishes regression coverage for existing behavior, and helps distinguish pre-existing defects from changes introduced by the new functionality.

## Commit

**Commit:** `cee9c09` — `Fix orders endpoint and add integration coverage`

Claude made the edits and ran `ruby -c`. It could not run the Rails test suite, because rubygems.org was blocked in its environment, so the test results above come from my local runs.

**Date:** 9 October 2026, 13:18:08 +0200.

The commit contains the baseline orders-controller fix and regression coverage.

## Outcome

The orders-controller syntax error has been fixed. The backend test suite passes with the new integration coverage, and checkout has been verified successfully in the iOS simulator.

The application now has a working baseline for the promo-code implementation.

---

# Step 3 — Promo-Code Architecture and API Design

**Status:** Initial architecture analysis complete. The design is under review and **has not been implemented**. No application code, migrations, tests, or mobile files were changed in this step.

## Objective

Design the promo-code feature before writing any code, grounded in the actual source rather than assumptions. The aim was to settle the data model, API contract, pricing rules, checkout behavior, and test strategy up front, so implementation could proceed in small, reviewable increments within the timebox.

## AI tool and setup

Claude was used against the local repository (the `take-home-assignment` folder on my machine), with read-only access for this step. Every finding below was produced by reading the source; nothing was executed against the application.

## Prompt used (verbatim)

> Step 3 — Promo-Code Architecture and API Design
> We have completed the baseline repair in a separate commit.
> Verified baseline:
>
> * Ruby 3.2.2 and Rails 7.0.10.
> * Orders integration tests: 3 runs, 15 assertions, 0 failures, 0 errors.
> * The iOS checkout flow succeeds.
> * The existing implementation has no promo-code functionality.
>
> I am working on a backend-focused take-home assignment. AI assistance is permitted, and I must document the prompts, implementation decisions, tests, and trade-offs.
> Strict constraint
> DO NOT modify any files. Do not generate migrations, implement models, change controllers, or edit the mobile application yet.
> Inspect the current repository and produce a design proposal grounded in the actual source code.
> Product requirements
>
> 1. Signed-in shoppers can enter a promo code in the shopping cart.
> 2. Valid codes show the discount and updated total before checkout.
> 3. Invalid codes explain why they failed.
> 4. Support percentage and fixed-amount discounts.
> 5. Codes can expire or be deactivated early.
> 6. Only one promo code can be applied per order.
> 7. Checkout persists the discounted amount.
> 8. Order history displays the discounted total.
>
> Task A — Inspect the existing implementation
> Inspect the relevant models, associations, database schema, routes, controllers, authentication, pricing calculations, checkout flow, order history, tests, fixtures, and React Native cart implementation.
> Identify the exact files and methods involved. Cite file paths and relevant code locations where possible.
> Distinguish verified facts from assumptions.
> Task B — Propose the data model
> Recommend the minimum schema changes required.
> Consider:
>
> * A PromoCode model with a unique code, discount type, discount value, active status, and optional expiration timestamp.
> * Validation of discount types and values.
> * How to associate an applied promo code with an order.
> * How to preserve the order's subtotal, discount amount, and final total.
> * Whether a nullable promo-code foreign key or a snapshot of the code on the order is appropriate.
> * Database constraints and indexes that provide meaningful protection.
>
> Do not add redemption limits, customer-specific eligibility, minimum purchase thresholds, or other features unless the brief or existing code requires them.
> Explain why each proposed field is necessary.
> Task C — Propose the API contract
> Recommend the smallest API change consistent with the existing application.
> Cover:
>
> * Applying or previewing a promo code.
> * Handling invalid, expired, and deactivated codes.
> * Removing an applied code.
> * Revalidating the code during checkout.
> * Returning the subtotal, discount, and final total.
> * Ensuring order history returns the persisted discounted amount.
>
> For every proposed endpoint, specify the HTTP method, path, request body, successful response, and important error responses.
> Inspect the current route conventions before recommending paths. Avoid adding separate endpoints if the existing API can support the workflow cleanly.
> Task D — Define pricing and checkout behavior
> Explain:
>
> * How the subtotal is calculated from the current cart.
> * How percentage and fixed discounts are calculated.
> * How to round monetary values consistently.
> * How to prevent a discount from exceeding the subtotal.
> * How the server remains authoritative for prices.
> * How checkout revalidates the promo code.
> * How order creation, order items, stock updates, and cart clearing should behave if any operation fails.
>
> Inspect the current transaction behavior and recommend the smallest safe correction needed for this feature.
> Do not introduce a payment-processing system; use the application's existing checkout semantics.
> Task E — Testing strategy
> Propose focused tests for:
>
> * Valid percentage discounts.
> * Valid fixed discounts.
> * Invalid codes.
> * Expired and deactivated codes.
> * Zero and excessive discounts.
> * Authentication and user isolation.
> * Removing or replacing a code.
> * Checkout persistence and order-history accuracy.
> * A code becoming invalid between preview and checkout.
> * Transaction rollback when checkout fails.
>
> Separate essential tests from optional improvements.
> Task F — Prioritized implementation plan
> Create a realistic plan for the remaining 2–3 hours.
> Prioritize backend correctness and automated tests, then the minimum mobile integration.
> For each increment, list:
>
> * Files expected to change.
> * Intended behavior.
> * Tests to run.
> * Completion criteria.
>
> Output format
> Return:
>
> 1. Verified architecture and relevant source locations.
> 2. Proposed models, associations, fields, constraints, and migrations.
> 3. Proposed API endpoints and example JSON responses.
> 4. Pricing and transaction decisions.
> 5. Essential and optional tests.
> 6. Expected file changes.
> 7. Prioritized implementation sequence.
> 8. Explicit assumptions and trade-offs.
> 9. Questions that require a product decision.
>
> Finish with a concise implementation recommendation.
> Do not modify any files. Wait for my review and approval before implementation.

## Key findings (verified from source at commit `cee9c09`)

- **Routes** (`backend/config/routes.rb`): cart routes are written by hand with singular paths (`get '/cart'`, `post '/cart/items'`, …) pointing at `cart#…`. Orders use `resources :orders, only: [:index, :create]`.
- **Authentication** (`backend/app/controllers/application_controller.rb`): the JWT `before_action` sets `@current_user`. Cart and order access always goes through `current_user.cart` / `current_user.orders`, and no route takes a cart or user id, so users are isolated by construction.
- **Pricing** (`backend/app/models/cart.rb`): `Cart#total` adds up `product.price.to_f * quantity` starting from `0.0`, so it is a **Float**. Its callers are `CartController#show` and `OrdersController#create`.
- **Checkout** (`OrdersController#create`): `order.save`, then a loop of **non-bang** `OrderItem.create` and `product.update(stock_quantity: …)`, then `cart.cart_items.destroy_all`, with no enclosing transaction. Because `Product` validates `stock_quantity >= 0`, an oversold item makes `update` return `false` silently: the order and order item are still created and stock is unchanged.
- **Order validation** (`backend/app/models/order.rb`): `total_amount > 0`, which would reject a fully discounted order.
- **Order history** (`OrdersController#index`): returns `total_amount`, `status`, `created_at` and items, with no subtotal or discount, and has N+1 queries.
- **Seeds** (`backend/db/seeds.rb`): the sample order's `total_amount` (89.97) does not match its items (18.99 + 79.99 = 98.98). This is pre-existing data inconsistency.
- **Mobile**:
  - `CartContext.tsx` already parses `total` when it arrives as a string.
  - `updateCartItem` is optimistic and never refreshes the cart, so totals go stale.
  - `CartScreen.tsx` posts `/orders` with no body and shows `error.response.data.error`.
  - `OrderHistoryScreen.tsx` shows only `total_amount`.

**Assumption still to verify:** that Rails 7.0 on SQLite writes `t.check_constraint` into `schema.rb`. Confirm this once the migration runs.

## Proposed design (under review, not implemented)

### Data model

- **New `promo_codes` table:**
  - `code`: unique, stored normalized with `strip.upcase`.
  - `discount_type`: `percentage` or `fixed`, as a string to match how `orders.status` is done.
  - `discount_value`: decimal(10,2), `> 0`; `<= 100` for percentages.
  - `active`: boolean, default true, for switching a code off early.
  - `expires_at`: nullable datetime.
  - Check constraints back up the model validations. `code` is read-only after creation.
- **`carts.promo_code_id`:** nullable foreign key. It holds the single code applied to the cart, so "one code per order" and "replace the code" fall out of the schema.
- **`orders`, three new columns:**
  - `subtotal_amount`: backfilled from `total_amount` for existing orders.
  - `discount_amount`: default 0.
  - `promo_code_id`: nullable foreign key, restrict delete.
  - `total_amount` keeps its meaning: **the amount paid**.
- **Foreign key vs. snapshot:** the proposal is the foreign key plus the persisted amounts, with the code made read-only. Add a code-string snapshot on orders later if codes become editable through an admin tool.

### API contract

| Method | Path | Body | Success | Errors |
|---|---|---|---|---|
| `GET` | `/api/cart` | — | 200: existing fields plus `subtotal`, `discount`, `total` (now the discounted total) and `promo_code` (including `valid` / `error_code` / `message` if the code has become invalid) | 401 |
| `PUT` | `/api/cart/promo_code` | `{ "code": "..." }` | 200: the full cart payload | 422 `{ error, error_code }` with `error_code` one of `blank`, `not_found`, `inactive`, `expired`; 401 |
| `DELETE` | `/api/cart/promo_code` | — | 200: the full cart payload (idempotent) | 401 |
| `POST` | `/api/orders` | none (unchanged) | 201: existing fields plus `subtotal_amount`, `discount_amount`, `promo_code` | 422 empty cart (existing); 422 code no longer valid; 422 checkout failure (rolled back) |
| `GET` | `/api/orders` | — | 200: each order adds `subtotal_amount`, `discount_amount`, `promo_code` | 401 |

### Pricing and checkout

- All money is **BigDecimal**. The subtotal is the sum of `price × quantity`.
- **Discount:**
  - percentage: `(subtotal × value / 100).round(2, half: :up)`;
  - fixed: `value`;
  - either way capped at the subtotal, so the total is never negative.
- Rounding happens once, on the discount, so `subtotal − discount = total` exactly.
- The client sends only the code. The server recomputes every amount from database prices on every request, including at checkout.
- **Checkout:**
  - wrap it in one transaction;
  - re-check the code before writing anything;
  - use `create!` / `update!`;
  - clear the cart's items and code on success;
  - return 422 on failure, with everything rolled back.
- This also fixes the silent oversell described above. `cart.lock!` is included for intent, but SQLite ignores row locks, so double-submit protection stays a known limitation.

### Tests and plan

- **Essential tests:**
  - model tests for validations, validity checks and discount math (rounding, cap, 100%, zero subtotal);
  - cart integration tests for apply, invalid reasons, replace, remove, auth and user isolation;
  - checkout tests for the persisted amounts, order history, a code invalidated between preview and checkout, and rollback on stock failure.
- **Planned increments** (about 2h50m, a commit each):
  1. schema;
  2. model and pricing;
  3. cart API;
  4. checkout and history;
  5. seeds and docs;
  6. minimal mobile;
  7. write-up.

## Trade-offs

- **Code stored on the cart vs. stateless.** The alternative was a `?promo_code=` parameter on `GET /cart` plus a body on `POST /orders`. It needs no new routes or column, but leaves the client holding the state. The proposal stores it on the cart, at the cost of two routes and one column.
- **An invalid code blocks checkout instead of being silently dropped.** This avoids charging more than the shopper was shown.
- **Specific error reasons reveal which codes exist.** This is accepted because the brief asks for the failure to be explained.
- **The discount sits at the order level and is not split per line item.** Partial refunds would need more work.
- **Cart JSON change:** the cart's `total` changes from a JSON number to a string. The mobile app already handles this.
- **Out of scope:** redemption limits, per-user eligibility, minimum spend and start dates.

## Open questions requiring a product decision

1. Can a code make an order free (total 0.00)? The proposal is yes, which means relaxing `total_amount > 0` to `>= 0`.
2. Should an invalidated code block checkout (proposed) or fall back to full price?
3. Are specific error reasons acceptable, or should there be one generic message?
4. Expiry semantics: an exact UTC instant (proposed), or end of day in a given time zone?
5. Does a second code replace the first (proposed) or get rejected?
6. Can a code be applied to an empty cart? The proposal allows it, with a discount of 0.

## Human review

I reviewed the initial proposal. The final design, including the open questions above, still needs my approval before any implementation starts.

## Verification

None yet. This step was analysis only: no commands were run against the application and no tests were added or rerun.

## Decisions

Pending final review. Everything under "Proposed design" is a proposal, not an implemented change.

## Supporting prompt: documentation update (summary, not verbatim)

After the design review, Claude was asked to update `PROMPTS.md` and `SUBMISSION.md` to record Step 3. The instructions were:

- preserve Steps 1 and 2;
- not claim anything as implemented or tested;
- label any reconstructed text as such;
- run `git diff --check`;
- leave application files untouched.

---

# Step 3b — Design Finalization

**Status:** Complete. The design was approved before implementation started.

## Prompts used (summary, not verbatim)

1. **Finalize the design.** I gave Claude a list of settled product and engineering decisions and asked for a read-only, source-grounded final design. It covered:
   - the exact migration sequence;
   - the exact API contract and error contract;
   - the pricing rules;
   - the smallest reliable checkout transaction;
   - mobile compatibility risks;
   - a test matrix;
   - a dependency-ordered implementation checklist with commands and time budgets.

   The prompt also set the incremental commit policy: implement, test, review the diff, get human approval, then commit.
2. **Final adjustments.** A follow-up asked for four changes:
   - verify the seed deletion order against the new foreign keys, and avoid destructive commands against the development database;
   - keep all checkout writes in one transaction, return 422 only for expected validation and stock failures, and let unexpected exceptions propagate;
   - use BigDecimal consistently;
   - tighten the timebox, making history UI polish optional.

## Decisions settled in this step

- **Settled before this step:**
  - a `PromoCode` model with percentage and fixed discounts;
  - codes normalized with trim and uppercase;
  - the applied code stored on the cart, where a successful apply replaces it and a failed apply leaves it unchanged;
  - orders store `subtotal_amount`, `discount_amount`, `total_amount` and the promo-code association;
  - BigDecimal math, with the discount rounded half-up and capped at the subtotal;
  - checkout re-checks the code and rejects an invalid one while keeping the cart;
  - atomic checkout;
  - zero-total orders supported.
- **Confirmed through the design review:**
  - a foreign key plus the stored amounts, with no code snapshot on the order;
  - `PUT` / `DELETE /api/cart/promo_code`, with errors as `{error, error_code}` and HTTP 422;
  - expiry is an exact UTC instant;
  - checkout rescues only `RecordInvalid` / `RecordNotSaved`, returning `insufficient_stock` or `checkout_failed`;
  - SQLite's lack of row locks is a documented limitation rather than something to fix.
- **Seed deletion order:** `User.destroy_all` cascades to carts and orders, and `PromoCode.destroy_all` runs last.
- **Rollback checks:** run only against the disposable test database, after backing up the development database.

These decisions supersede the "Pending" entries in Step 3.

---

# Step 4 — Implementation and Testing

**Status:** In progress. Increments 1–5 and one pre-existing bug fix are complete and committed. Increment 6 (final review) is recorded under Step 5.

## Increment 1 — Schema and seeds

### Prompt used (verbatim)

> Approved. Start Increment 1 (schema and seeds).
> Follow this interaction protocol throughout the implementation: [the seven-point protocol: ask before ambiguous or destructive steps; one increment at a time; explicit "ACTION REQUIRED" commands for me to run; report only verified results; review the diff and `git status --short` before any commit; keep the conversation concise; keep PROMPTS.md/SUBMISSION.md and unrelated files out of feature commits].
> For Increment 1, first inspect the current working tree and the relevant migrations, schema, fixtures, and seeds. If you find a new issue that affects the approved plan, ask me before proceeding. Otherwise, implement Increment 1 and stop at the review-and-verification stage. Do not commit yet.

The protocol text in brackets is condensed; everything else is quoted as given.

### Changes

- **Three migrations:**
  - `create_promo_codes`: a unique index on `code`, plus four named check constraints covering code normalization, discount type, a positive value, and percentages up to 100.
  - `add_promo_code_to_carts`: nullable, and deleting a code clears it from carts.
  - `add_pricing_to_orders`, in this order:
    1. add the new columns as nullable;
    2. backfill `subtotal_amount = total_amount`;
    3. set NOT NULL;
    4. add the check constraints last, so SQLite's table rebuilds can't drop them.
- `db/schema.rb`, regenerated by `bin/rails db:migrate`.
- `test/fixtures/orders.yml`: added `subtotal_amount`.
- `db/seeds.rb`: the sample order gets `subtotal_amount: 89.97`. The pre-existing mismatch between that total and its items was left as it is.
- `OrdersController#create`: a temporary compatibility line. It records the undiscounted cart sum as both `subtotal_amount` and `total_amount`, so checkout keeps working until promo pricing arrives in Increment 4.

### Issues found and how they were resolved

1. **Seeding promo codes needs the model.** The seed lines would have failed before `PromoCode` existed. Claude raised this before writing them; I chose to defer them to Increment 2.
2. **Checkout failed after migrating.** The first test run failed with `NOT NULL constraint failed: orders.subtotal_amount` from `OrdersController#create`, the expected result of the new column. Claude offered three options:
   - A: set the subtotal explicitly in the controller;
   - B: give the column a database default;
   - C: commit with the test failing.

   I chose A. B could silently record a wrong subtotal, and C would have left the increment broken.
3. **`git diff --stat db/schema.rb` printed nothing.** The cause was the pager. My shell sets `LESS=-R`, so git does not add its usual `F` and `X` flags, and `less` cleared its output when it closed. `git --no-pager diff --stat` showed the expected 27 insertions and 1 deletion.

### Verification

Claude ran `ruby -c` on the migrations, the seeds and the controller (all `Syntax OK`), and `git diff --check` (clean). I ran all Rails commands locally:

| Command | Result |
|---|---|
| Development DB backup (`cp … development.sqlite3-backup-20261009143802`) | Created; ignored by git |
| `bin/rails db:migrate` (development) | All 3 migrations applied. Existing orders backfilled (subtotal = total, discount 0); carts have a nil `promo_code_id` |
| `grep check_constraint db/schema.rb` | All 7 check constraints and both foreign keys present |
| `RAILS_ENV=test bin/rails db:drop db:create db:migrate`, then `db:rollback STEP=3`, then `db:migrate` | Rolled back and re-applied cleanly |
| `bin/rails test` (before the compatibility fix) | 3 runs, 1 error (`NOT NULL constraint failed: orders.subtotal_amount`) |
| `bin/rails db:migrate:status` | All 3 new migrations `up` |
| `bin/rails test test/integration/orders_test.rb -v` (after the fix) | 3 runs, 15 assertions, 0 failures, 0 errors |
| `bin/rails test` (after the fix) | 3 runs, 15 assertions, 0 failures, 0 errors |
| `git diff --check` | Clean |

`db:seed` was deliberately not run. It wipes the development database and is scheduled for Increment 2.

### Commit

`43348c0` — *Add promo code schema and order pricing columns*. It contains 7 files: the three migrations, `schema.rb`, `seeds.rb`, `orders.yml` and `orders_controller.rb`. The iOS setup changes, `PROMPTS.md` and `SUBMISSION.md` were not included.

### Remaining for later increments

- the `PromoCode` model and its seeds (Increment 2);
- promo pricing in checkout (Increment 4).

## Increment 2 — PromoCode model and BigDecimal pricing

### Prompt used (verbatim)

> Keep `PROMPTS.md` and `SUBMISSION.md` uncommitted until Increment 6. Thanks for documenting Increment 1; keep recording actual outcomes as we progress, without staging or committing either file.
> Start Increment 2: `PromoCode` model, BigDecimal pricing on `Cart` and `Order`, model tests, and deferred seed changes.
> Follow our agreed workflow:
>
> * Inspect the current state and the Increment 1 commit before editing.
> * Ask me first if a genuine ambiguity or potentially destructive operation arises.
> * Implement only Increment 2.
> * Do not run `db:seed` or any destructive database operation without my explicit approval.
> * Run the checks available to you, then give me the exact Rails test commands to run, from the correct directory.
> * Report changed files, actual verification results, and `git status --short`.
> * Do not stage or commit anything. Wait for my test output and explicit approval before proceeding.

### Changes

- **`PromoCode` (new):**
  - codes are normalized (trim and upcase) on save, and looked up the same way with `find_by_normalized_code`;
  - `attr_readonly :code`;
  - type and value validations that mirror the database constraints;
  - `unusable_reason(at)` returns `:inactive` or `:expired`, and a code counts as expired from its exact `expires_at` instant;
  - `discount_for(subtotal)` raises `ArgumentError` for anything other than a BigDecimal, rounds with `BigDecimal::ROUND_HALF_UP` to cents, and caps at the subtotal;
  - deleting a code clears it from carts, and a code used by an order cannot be deleted.
- **`Cart`:**
  - `subtotal` adds up the item subtotals starting from `BigDecimal("0")`;
  - `price_breakdown(at)` returns `{subtotal, discount, total}`, and an unusable code gives no discount;
  - `total` now means subtotal minus any usable discount. The old Float calculation was removed.
- **`Order`:** a `promo_code` association; all three amounts must be ≥ 0, so zero totals are allowed; discount ≤ subtotal; and total = subtotal − discount.
- **Checkout compatibility line** now uses `cart.subtotal`, so `subtotal_amount` stays pre-discount now that `Cart#total` can include a discount.
- **Seeds:** `PromoCode.destroy_all` runs last, and five codes are seeded: `WELCOME10`, `SAVE5`, `MAKEGOOD50`, `EXPIRED20`, `RETIRED15`.
- **Tests:** a new `promo_codes.yml` fixture, plus 33 model tests across `promo_code_test.rb`, `cart_test.rb` and `order_test.rb`. They replace the commented-out stubs.

### Side effects noted at review

- `GET /api/cart` now returns `total` as a string (BigDecimal) instead of a JSON number. The mobile app already accepts both.
- Checkout still ignores any attached code until Increment 4.

### Verification

Claude ran:

- `ruby -wc` on all 8 Ruby files: `Syntax OK`, no warnings.
- A fixture YAML parse: all 7 fixtures parse with the expected values.
- `grep "to_f\|0\.0" app/models app/controllers`: no matches.
- `git diff --check`: clean.

I ran the Rails commands:

| Command | Result |
|---|---|
| `bin/rails test test/models -v` | 33 runs, 75 assertions, 0 failures, 0 errors |
| `bin/rails test` | 36 runs, 90 assertions, 0 failures, 0 errors |
| `bin/rails runner '… price_breakdown'` (before seeding) | `{subtotal: 0.0, discount: 0.0, total: 0.0}`. The development cart was empty after an earlier checkout, so this line cannot distinguish BigDecimal from Float; the type is covered by the tests. |
| Backup, then `bin/rails db:seed && bin/rails db:seed` | Both runs succeeded. The second run confirms the deletion order works with existing promo codes. |
| `PromoCode.order(:code).pluck(…)` | All 5 seeded codes have the expected type, value, active flag and expiry |

### Commit

`8204515` — *Add PromoCode model and BigDecimal cart pricing* (9 files). The iOS setup changes, `PROMPTS.md` and `SUBMISSION.md` were not included.

## Increment 3 — Cart promo-code API

### Prompt used (verbatim)

> Start Increment 3: cart promo-code API and integration tests.
> Follow our established workflow:
>
> * Inspect the current working tree and confirm Increment 2's commit and test status.
> * Implement only the agreed cart API changes: `PUT` and `DELETE /api/cart/promo_code`, a shared cart response, and the agreed `{error, error_code}` error contract.
> * Preserve the existing applied code if a replacement attempt fails.
> * Keep authentication and per-user cart isolation intact.
> * Add the planned integration tests.
> * Do not run seeds, destructive database operations, stage, or commit anything.
> * Run the checks available to you and give me the exact Rails test commands to run from the correct directory.
> * Report changed files, actual test results, and `git status --short`. Flag any genuine new ambiguity before making a consequential change.
> * Stop for my review and wait for my test output and explicit approval before committing or starting another increment.
>
> Keep `PROMPTS.md` and `SUBMISSION.md` uncommitted until Increment 6.

### Changes

- **Routes:** `put '/cart/promo_code'` → `cart#apply_promo_code` and `delete '/cart/promo_code'` → `cart#remove_promo_code`, written in the existing hand-written cart-route style.
- **`CartController`:**
  - A private `cart_payload` is shared by `show`, apply and remove. It keeps the existing `items` shape and adds `subtotal`, `discount`, `total` (a live preview, as BigDecimal strings) and `promo_code` (`code`, `discount_type`, `discount_value`, `valid`, `error_code`, `message`).
  - Pricing and code validity are evaluated at a single timestamp, so they always agree.
  - **Apply** checks blank, then not found, then inactive or expired. Every failure returns 422 `{error, error_code}` before any write, so a previously applied code is kept. Only a valid code calls `cart.update!`.
  - **Remove** is idempotent.
  - Items are now loaded with their products in one query.
  - `add_item`, `update_item` and `remove_item` are unchanged.
- **`PromoCode`:** `ERROR_MESSAGES` and `PromoCode.error_message`, which checkout will reuse in Increment 4.
- **Tests:**
  - `test/integration/cart_promo_code_test.rb`: 17 tests;
  - `promo_code_test.rb`: one message test.

No new ambiguity came up in this increment.

### Verification

Claude ran `ruby -wc` on all changed files (`Syntax OK`, no warnings) and `git diff --check` (clean). I ran the Rails commands:

| Command | Result |
|---|---|
| `bin/rails routes -g promo_code` | `PUT` and `DELETE /api/cart/promo_code` → `api/cart#apply_promo_code` / `#remove_promo_code` |
| `bin/rails test test/integration/cart_promo_code_test.rb -v` | 17 runs, 115 assertions, 0 failures, 0 errors |
| `bin/rails test` | 54 runs, 210 assertions, 0 failures, 0 errors. The suite now exceeds Rails' threshold of 50 tests, so it runs in parallel across 8 processes. |
| Manual curl check against seeded data (`bin/rails server`) | `" welcome10 "` → subtotal `118.94`, discount `11.89`, total `107.05`, `valid: true`. `EXPIRED20` → `{"error":"This promo code has expired.","error_code":"expired"}`. Remove → discount `0.0`, total `118.94`, `promo_code: null`. |

**Gap in the manual check:** the curl sequence did not fetch the cart between the rejected `EXPIRED20` and the removal. Keeping the current code after a failed replacement is covered by the integration test "a failed replacement keeps the currently applied code", which checks all four error codes.

### Commit

`7860c25` — *Add cart promo code API with shared cart response* (5 files). The iOS setup changes, `PROMPTS.md` and `SUBMISSION.md` were not included.

## Increment 4 — Atomic checkout and order history

### Prompt used (verbatim)

> Start Increment 4: atomic checkout and order history.
>
> * Re-check the applied promo code at checkout.
> * Persist `subtotal_amount`, `discount_amount`, `total_amount` and the promo-code association.
> * Keep all checkout writes inside one database transaction, using exception-raising writes so failures roll back the order, items, stock changes and cart clearing.
> * Return 422 only for expected checkout failures; allow unexpected exceptions to propagate.
> * Add tests for successful checkout, no-code checkout, invalidated codes, zero-total orders, rollback after a partial write, and persisted order-history values.
> * Preserve the existing API contract except for the agreed additions and error responses.
>
> Before editing, verify the working tree and the state of Increment 3. If it hasn't been verified and committed, stop and tell me what's missing.
> Implement only Increment 4. Do not run seeds or destructive database operations, stage files, or commit anything. Run available checks, then give me the exact Rails test commands to run from the correct directory. Report changed files, actual verification results and `git status --short`. Ask me before resolving any consequential new ambiguity, and stop for my review and explicit approval.
> Keep `PROMPTS.md` and `SUBMISSION.md` uncommitted until Increment 6.

### Changes

- **`OrdersController#create`:**
  1. An empty cart returns 422, as before.
  2. The applied code is checked again before any write, using the same timestamp as the pricing. An inactive or expired code returns 422 `{error: "<message> Remove it to check out.", error_code}`, and the cart, its code and stock are left untouched.
  3. One transaction runs `Order.create!` (with subtotal, discount, total and the code), then `OrderItem.create!` and `product.update!` for each item, then `destroy!` on each cart item, then `cart.update!(promo_code: nil)`.
  4. Only `RecordInvalid` and `RecordNotSaved` are rescued, after the rollback. A stock failure returns 422 `insufficient_stock`; any other validation failure returns 422 `checkout_failed`. Every other exception propagates.

  This replaced the temporary compatibility line from Increment 1.
- **Order responses:** the create response and each order in history now include `subtotal_amount`, `discount_amount` and `promo_code` (the code string or null) alongside the existing fields. History loads codes, items and products without a query per order.
- **Tests (`test/integration/orders_test.rb`):** the 3 existing tests were updated to expect the added fields, and 9 tests were added:
  - order history keeps the stored amounts after the code is deactivated and the product price changes;
  - an empty cart is rejected;
  - checkout with a valid code;
  - checkout through the cart API;
  - a zero-total order;
  - a code deactivated after applying, and a code that expires after applying, with time moved forward;
  - rollback after partial writes, where a second item's stock is too low and orders, order items, stock, cart items and the code are all unchanged;
  - an unexpected `RuntimeError`, injected into `OrderItem.create!`, propagates and the transaction still rolls back.

**Difference from the design example:** checkout error messages reuse the existing messages with "Remove it to check out." appended, instead of naming the code in the message. The `error_code` values match the design. No new ambiguity came up.

### Verification

Claude ran `ruby -wc` on both files (`Syntax OK`, no warnings), the float grep over models and controllers (no matches) and `git diff --check` (clean). I ran the Rails commands:

| Command | Result |
|---|---|
| `bin/rails test test/integration/orders_test.rb -v` | 12 runs, 100 assertions, 0 failures, 0 errors |
| `bin/rails test` | 63 runs, 295 assertions, 0 failures, 0 errors (parallel, 8 processes) |
| Manual checkout via curl (`WELCOME10` on the seeded cart) | `201` with `subtotal_amount 118.94`, `discount_amount 11.89`, `total_amount 107.05`, `promo_code WELCOME10` (order #2). `GET /api/orders` returns the same values. |

The manual check changed the development data: the seeded user now has order #2, an empty cart and reduced stock.

### Commit

`15fac2e` — *Make checkout atomic and persist promo pricing on orders* (2 files). The iOS setup changes, `PROMPTS.md` and `SUBMISSION.md` were not included.

## Increment 5 — Mobile promo-code flow

### Prompt used (verbatim)

> Start Increment 5: implement the essential mobile promo-code flow as agreed.
> Update the cart/order types, add promo-code apply/remove and quiet cart refresh in `CartContext.tsx`, and update `CartScreen.tsx` with the code input, inline errors, and subtotal/discount/total breakdown. Refresh after failed checkout. Keep the existing checkout request contract.
> Follow our established workflow and stop for my review before committing. Tell me if you encounter a genuine blocker or need me to run something; otherwise, avoid repeating previously agreed instructions.

### Changes (`mobile/src`)

- **`types/index.ts`:**
  - the cart type gains `subtotal`, `discount` and `promo_code` (code, type, value, `valid`, `error_code`, `message`);
  - the order type gains `subtotal_amount`, `discount_amount` and `promo_code`;
  - comments mark which amounts are a live preview and which were persisted at checkout.
- **`CartContext.tsx`:**
  - one helper converts money strings to numbers;
  - `refreshCart({ quiet: true })` refetches without the full-screen spinner;
  - `updateCartItem` still updates instantly on screen, then refetches quietly once the PATCH succeeds or fails, so totals and discounts are recalculated and a rejected change is undone;
  - `applyPromoCode` and `removePromoCode` set the cart from the response, and errors reach the screen.
- **`CartScreen.tsx`:**
  - a promo section at the top of the item list: an input, Apply (or Replace once a code is applied), Remove, the server's inline error, and the message for an applied code that is no longer valid;
  - Subtotal and Discount rows in the footer, above Total;
  - a quiet cart refresh after a failed checkout;
  - the checkout request is unchanged.
- **`OrderHistoryScreen.tsx`:** parses the two new money fields, with no UI change. The discount line in order history was left as optional.

**Design note:** the input sits at the top of the list rather than in the footer. At the bottom of the screen the iOS keyboard would cover it, and fixing that properly needs the stack header height, which `@react-navigation/stack` v6 does not export.

### Verification

Claude ran:

- `tsc --noEmit`: exit 0.
- ESLint on the 4 files: 3 errors, all in lines that existed before. The same files at the previous commit had 5.
- `git diff --check`: clean.

I ran the iOS simulator walkthrough:

- **Passed:** applying a code, invalid codes, replacing, removing, a quantity change, and checkout.
- **Not run in the simulator:** the optional zero-total and invalidated-before-checkout paths. Both are covered by backend integration tests.
- **Found:** a pre-existing bug where adding a product showed one more than requested. See the fix below.

### Commit

`19f2381` — *Add promo code flow to the mobile cart* (4 files).

## Pre-existing bug fix — add-to-cart quantity off by one

### How it was found

During the Increment 5 walkthrough, adding 2 of a product showed 3 in the cart.

### Diagnosis

Claude traced it to `CartController#add_item`. It calls `find_or_initialize_by` and then adds the requested quantity to `cart_item.quantity`. A new cart item already holds the column default of 1 (`schema.rb`), so the first add of any product stored one more than requested. As a side effect, adding the last unit in stock was rejected as "exceeds available stock". `git blame` showed these lines date from the initial commit `4ae342c`; Increment 5 did not touch this code.

### Process

1. Claude proposed committing Increment 5 first and making the fix as a separate commit. I agreed.
2. The fix treats a new cart item's existing quantity as 0.
3. A new `test/integration/cart_items_test.rb` covers four cases: a new product with quantity 2, a new product with no quantity, adding again to an existing line, and adding the last unit in stock.

### Verification

I ran:

| Command | Result |
|---|---|
| `git stash push -- app/controllers/api/cart_controller.rb`, then `bin/rails test test/integration/cart_items_test.rb`, then `git stash pop` | Old code: 4 runs, **4 failures**. Expected 2, got 3; expected 1, got 2; expected 3, got 4; and 422 "Quantity exceeds available stock" for the last unit. |
| `bin/rails test test/integration/cart_items_test.rb -v` | Fixed code: 4 runs, 8 assertions, 0 failures |
| `bin/rails test` | 67 runs, 303 assertions, 0 failures, 0 errors |

**Where the AI was wrong:** Claude predicted 3 failures on the old code. In fact all 4 failed: the "adding again" test also failed, because its first add had already overshot by one. The bug therefore affected every flow that starts by adding a new product.

### Commit

`0a98f4d` — *Fix off-by-one quantity when adding a new product to the cart* (2 files). The iOS setup changes, `PROMPTS.md` and `SUBMISSION.md` were not included.

---

# Step 5 — Final Review and Submission (Increment 6)

**Status:** Complete. The final regression and seeded-code checks passed (below). The docs go into one final commit; the walkthrough video link will be added in a later follow-up commit.

## Prompt used (verbatim)

> Start Increment 6. The feature commits are complete; do the final regression run, review the full branch diff, and update `backend/README.md`, `SUBMISSION.md` and `PROMPTS.md` as described.
> Keep the review focused: verify the actual implementation and test evidence, check that the README's seeded promo codes really exist and work, and correct any stale or unsupported claims in the docs. Don't run seeds or destructive database commands without asking me first.
> Show me the final diff and test results, then ask how I want to commit `PROMPTS.md` and `SUBMISSION.md`. Don't commit those docs until I explicitly approve.

## Review of the full branch (`4ae342c..0a98f4d`)

- **Scope:** 24 files (1,373 insertions, 91 deletions): backend models, controllers, routes, 3 migrations, schema, seeds, fixtures, tests, and 4 mobile source files. No iOS project or setup files are in any feature commit.
- **Checks Claude re-ran on the final code:** `ruby -wc` on every changed backend Ruby file (all OK) and `tsc --noEmit` in `mobile/` (exit 0).
- **Claims cross-checked against the code and recorded test evidence:**
  - the seeded codes match `db/seeds.rb`;
  - the error codes and messages match `PromoCode::ERROR_MESSAGES`;
  - the checkout behavior matches `OrdersController#create`.

## Documentation corrections

- **`PROMPTS.md`:**
  - the tool is now described as Claude in the Claude desktop app (Cowork), not "Claude Code", with the division of work between Claude and me stated explicitly;
  - added a summary for reviewers covering where the AI was wrong and where we changed direction;
  - Step 1's prompt is labelled as lightly reformatted;
  - Step 2 now records the commit hash and that I ran its tests;
  - removed the unused per-increment template.
- **`SUBMISSION.md`:** restructured to the README's required headings, with the commit table, how to run, codes to try, decisions, testing evidence, pre-existing issues and next steps. The outdated "promo-code implementation not yet complete" statement was removed.
- **`backend/README.md`:**
  - the promo-code endpoints, cart payload and error contract;
  - the order pricing fields and checkout behavior;
  - the `PromoCode` model;
  - the seeded codes, with a warning that seeding wipes data.

## Final verification

I ran these on the final code (`0a98f4d`, plus documentation changes only):

| Check | Result |
|---|---|
| `bin/rails test` | 67 runs, 303 assertions, 0 failures, 0 errors, 0 skips (parallel, 8 processes) |
| Seeded codes check (read-only `bin/rails runner`, looking up `welcome10` in lowercase) | All 5 codes exist. `WELCOME10`, `SAVE5` and `MAKEGOOD50` are usable, with discounts of 11.89 / 5.00 / 50.00 on 118.94 and 2.00 / 5.00 / 20.00 (capped) on 20.00. `EXPIRED20` reports `:expired` and `RETIRED15` (`active=false`) reports `:inactive`. |
| `git diff --check` | Clean |

The runner called `discount_for` directly, so it also printed raw discounts for `EXPIRED20` and `RETIRED15`. Those codes are never applied: the cart API rejects them, and the cart pricing gives an unusable code no discount, as covered by the tests.

## Time log

**How this was measured:** Claude derived these figures from the timestamps in this session's log, from when each prompt was sent to Claude's last reply for that prompt, plus the git commit times.
- They are wall-clock times in Europe/Berlin.
- "Claude time" is how long Claude worked on a prompt, including tool calls. It slightly undercounts, because it ends when the final reply starts rather than when it finishes.
- Everything else in a phase is my time: reading, reviewing diffs, running commands and tests, simulator checks and committing.

| Phase | Window | Duration |
|---|---|---|
| Step 1 — Discovery (previous night) | 01:32 → 01:34 | about 2 min of Claude time, then a break |
| Step 2 — Baseline repair | 13:04 → commit 13:18 | 13 min |
| Steps 3 / 3b — Design, review, finalization and doc update | 13:29 → 14:18 | 49 min |
| Increment 1 — Schema and seeds | 14:18 → commit 14:45 | 27 min |
| Increment 2 — Model and pricing | 14:48 → commit 14:53 | 6 min |
| Increment 3 — Cart API | 14:55 → commit 15:02 | 7 min |
| Increment 4 — Atomic checkout and history | 15:04 → commit 15:11 | 7 min |
| Increment 5 and the add-to-cart bug fix | 15:14 → commit 15:31 | 17 min |
| Increment 6 — Final review and docs | 15:33 → commit 15:48 | 15 min |
| **Active window (13:04 → 15:48)** | | **2 h 44 min** |

**Claude's processing time:** about 29 minutes in total across 29 prompts (the time-log request itself excluded).
- Average: about **1 minute per prompt**.
- Longest: about 3 minutes, for the design finalization (Step 3b) and Increment 6.
- Shortest: about 10 seconds, for acknowledging test output.

The remaining ~2 h 15 min of the window was my own work.


`mobile/ios/MobileApp.xcodeproj/project.pbxproj`, `mobile/ios/MobileApp/Info.plist`, `mobile/package-lock.json`, `mobile/ios/MobileApp.xcworkspace/` and `mobile/ios/Podfile.lock` were changed or created by `pod install`, `npm install` and running the app locally. They are environment setup, not feature code, so no commit includes them.

I asked why the mobile work seemed uncommitted. Claude explained that the mobile feature code is in `19f2381`, and that these remaining files are local setup artifacts that could change how the app builds for reviewers.
