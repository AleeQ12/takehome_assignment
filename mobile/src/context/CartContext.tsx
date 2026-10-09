import React, { createContext, useState, useContext, ReactNode, useEffect } from 'react';
import { Cart } from '../types';
import api from '../services/api';
import { useAuth } from './AuthContext';

interface RefreshOptions {
  // Refetch without toggling isLoading, so the cart screen does not swap to a spinner.
  quiet?: boolean;
}

interface CartContextType {
  cart: Cart | null;
  isLoading: boolean;
  refreshCart: (options?: RefreshOptions) => Promise<void>;
  addToCart: (productId: number, quantity?: number) => Promise<void>;
  updateCartItem: (itemId: number, quantity: number) => Promise<void>;
  removeFromCart: (itemId: number) => Promise<void>;
  // Both reject with the API error (422 carries { error, error_code }) for the caller to display.
  applyPromoCode: (code: string) => Promise<void>;
  removePromoCode: () => Promise<void>;
}

const CartContext = createContext<CartContextType | undefined>(undefined);

// The API serializes money as decimal strings; convert them to numbers for display.
const toNumber = (value: unknown): number =>
  typeof value === 'string' ? parseFloat(value) : (value as number);

const normalizeCart = (data: any): Cart => ({
  ...data,
  items: (data.items ?? []).map((item: any) => ({
    ...item,
    product: {
      ...item.product,
      price: toNumber(item.product?.price),
    },
    subtotal: toNumber(item.subtotal),
  })),
  subtotal: toNumber(data.subtotal),
  discount: toNumber(data.discount),
  total: toNumber(data.total),
  promo_code: data.promo_code
    ? { ...data.promo_code, discount_value: toNumber(data.promo_code.discount_value) }
    : null,
});

export const CartProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [cart, setCart] = useState<Cart | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const { isAuthenticated } = useAuth();

  useEffect(() => {
    if (isAuthenticated) {
      refreshCart();
    }
  }, [isAuthenticated]);

  const refreshCart = async ({ quiet = false }: RefreshOptions = {}) => {
    if (!isAuthenticated) return;
    try {
      if (!quiet) setIsLoading(true);
      const response = await api.get('/cart');
      setCart(normalizeCart(response.data));
    } catch (error) {
      console.error('Error fetching cart:', error);
    } finally {
      if (!quiet) setIsLoading(false);
    }
  };

  const addToCart = async (productId: number, quantity: number = 1) => {
    try {
      await api.post('/cart/items', { product_id: productId, quantity });
      await refreshCart();
    } catch (error) {
      console.error('Error adding to cart:', error);
      throw error;
    }
  };

  const updateCartItem = async (itemId: number, quantity: number) => {
    // Optimistic update for a snappier cart
    if (cart) {
      setCart({
        ...cart,
        items: cart.items.map(item =>
          item.id === itemId ? { ...item, quantity } : item
        ),
      });
    }
    // Then resync from the server so subtotal, discount and total are recalculated
    // (and a rejected update is reverted).
    api
      .patch(`/cart/items/${itemId}`, { quantity })
      .catch(error => {
        console.error('Error updating cart item:', error);
      })
      .finally(() => refreshCart({ quiet: true }));
  };

  const removeFromCart = async (itemId: number) => {
    try {
      await api.delete(`/cart/items/${itemId}`);
      await refreshCart();
    } catch (error) {
      console.error('Error removing from cart:', error);
      throw error;
    }
  };

  const applyPromoCode = async (code: string) => {
    const response = await api.put('/cart/promo_code', { code });
    setCart(normalizeCart(response.data));
  };

  const removePromoCode = async () => {
    const response = await api.delete('/cart/promo_code');
    setCart(normalizeCart(response.data));
  };

  return (
    <CartContext.Provider
      value={{
        cart,
        isLoading,
        refreshCart,
        addToCart,
        updateCartItem,
        removeFromCart,
        applyPromoCode,
        removePromoCode,
      }}
    >
      {children}
    </CartContext.Provider>
  );
};

export const useCart = () => {
  const context = useContext(CartContext);
  if (context === undefined) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
};
