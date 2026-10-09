export interface User {
  id: number;
  email: string;
}

export interface Product {
  id: number;
  name: string;
  description: string;
  price: number;
  image_url: string;
  stock_quantity: number;
}

export interface CartItem {
  id: number;
  product: Product;
  quantity: number;
  subtotal: number;
}

export interface AppliedPromoCode {
  code: string;
  discount_type: 'percentage' | 'fixed';
  discount_value: number;
  // false when the code has expired or been deactivated since it was applied
  valid: boolean;
  error_code: string | null;
  message: string | null;
}

// subtotal/discount/total are a live server-side preview; they are not persisted.
export interface Cart {
  id: number;
  items: CartItem[];
  subtotal: number;
  discount: number;
  total: number;
  promo_code: AppliedPromoCode | null;
}

export interface OrderItem {
  product_name: string;
  quantity: number;
  price: number;
  subtotal: number;
}

// Amounts persisted at checkout; total_amount is the amount paid.
export interface Order {
  id: number;
  subtotal_amount: number;
  discount_amount: number;
  total_amount: number;
  promo_code: string | null;
  status: string;
  created_at: string;
  items: OrderItem[];
}

export interface AuthResponse {
  token: string;
  user: User;
}

