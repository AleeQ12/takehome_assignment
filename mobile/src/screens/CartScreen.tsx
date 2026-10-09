import React, { useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  StyleSheet,
  ActivityIndicator,
  Alert,
  TouchableOpacity,
  TextInput,
} from 'react-native';
import { CartItem } from '../components/CartItem';
import { Button } from '../components/Button';
import { useCart } from '../context/CartContext';
import { useAuth } from '../context/AuthContext';
import api from '../services/api';

export const CartScreen: React.FC<{ navigation: any }> = ({ navigation }) => {
  const {
    cart,
    isLoading,
    refreshCart,
    updateCartItem,
    removeFromCart,
    applyPromoCode,
    removePromoCode,
  } = useCart();
  const { isAuthenticated } = useAuth();
  const [checkoutLoading, setCheckoutLoading] = React.useState(false);
  const [promoInput, setPromoInput] = React.useState('');
  const [promoError, setPromoError] = React.useState<string | null>(null);
  const [promoLoading, setPromoLoading] = React.useState(false);

  useEffect(() => {
    if (isAuthenticated) {
      refreshCart();
    }
  }, [isAuthenticated]);

  // The server validates and normalizes the code; its 422 { error } message is shown inline.
  const handleApplyPromo = async () => {
    setPromoError(null);
    setPromoLoading(true);
    try {
      await applyPromoCode(promoInput);
      setPromoInput('');
    } catch (error: any) {
      setPromoError(error.response?.data?.error || 'Could not apply promo code. Please try again.');
    } finally {
      setPromoLoading(false);
    }
  };

  const handleRemovePromo = async () => {
    setPromoError(null);
    setPromoLoading(true);
    try {
      await removePromoCode();
    } catch (error: any) {
      setPromoError(error.response?.data?.error || 'Could not remove promo code. Please try again.');
    } finally {
      setPromoLoading(false);
    }
  };

  const handleCheckout = async () => {
    if (!cart || cart.items.length === 0) {
      Alert.alert('Empty Cart', 'Your cart is empty');
      return;
    }

    try {
      setCheckoutLoading(true);
      const response = await api.post('/orders');
      Alert.alert('Success', 'Order placed successfully!', [
        {
          text: 'OK',
          onPress: () => {
            refreshCart();
            navigation.navigate('OrderHistory');
          },
        },
      ]);
    } catch (error: any) {
      Alert.alert('Error', error.response?.data?.error || 'Failed to place order');
      // Show the server's current view, e.g. a promo code that is no longer valid.
      refreshCart({ quiet: true });
    } finally {
      setCheckoutLoading(false);
    }
  };

  if (!isAuthenticated) {
    return (
      <View style={styles.center}>
        <Text style={styles.message}>Please login to view your cart</Text>
        <Button title="Login" onPress={() => navigation.navigate('Login')} />
      </View>
    );
  }

  if (isLoading) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  if (!cart || cart.items.length === 0) {
    return (
      <View style={styles.center}>
        <Text style={styles.emptyText}>Your cart is empty</Text>
        <Button
          title="Browse Products"
          onPress={() => navigation.navigate('ProductList')}
          variant="secondary"
        />
      </View>
    );
  }

  const appliedPromo = cart.promo_code;

  const promoSection = (
    <View style={styles.promoContainer}>
      <Text style={styles.promoTitle}>Promo code</Text>
      <View style={styles.promoRow}>
        <TextInput
          style={styles.promoInput}
          value={promoInput}
          onChangeText={text => {
            setPromoInput(text);
            setPromoError(null);
          }}
          placeholder="Enter code"
          autoCapitalize="characters"
          autoCorrect={false}
          returnKeyType="done"
          onSubmitEditing={handleApplyPromo}
          editable={!promoLoading}
        />
        <TouchableOpacity
          style={[styles.promoButton, promoLoading && styles.promoButtonDisabled]}
          onPress={handleApplyPromo}
          disabled={promoLoading}
        >
          {promoLoading ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.promoButtonText}>{appliedPromo ? 'Replace' : 'Apply'}</Text>
          )}
        </TouchableOpacity>
      </View>
      {promoError ? <Text style={styles.promoError}>{promoError}</Text> : null}
      {appliedPromo ? (
        <View style={styles.appliedRow}>
          <Text style={styles.appliedText}>
            Applied: <Text style={styles.appliedCode}>{appliedPromo.code}</Text>
          </Text>
          <TouchableOpacity onPress={handleRemovePromo} disabled={promoLoading}>
            <Text style={styles.removeText}>Remove</Text>
          </TouchableOpacity>
        </View>
      ) : null}
      {appliedPromo && !appliedPromo.valid && appliedPromo.message ? (
        <Text style={styles.promoError}>
          {appliedPromo.message} Remove it or enter a different code.
        </Text>
      ) : null}
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        data={cart.items}
        ListHeaderComponent={promoSection}
        keyboardShouldPersistTaps="handled"
        renderItem={({ item }) => (
          <CartItem
            item={item}
            onUpdateQuantity={updateCartItem}
            onRemove={removeFromCart}
          />
        )}
        keyExtractor={(item) => item.id.toString()}
        contentContainerStyle={styles.list}
      />
      <View style={styles.footer}>
        <View style={styles.breakdownRow}>
          <Text style={styles.breakdownLabel}>Subtotal</Text>
          <Text style={styles.breakdownValue}>${cart.subtotal.toFixed(2)}</Text>
        </View>
        {cart.discount > 0 ? (
          <View style={styles.breakdownRow}>
            <Text style={styles.discountLabel}>
              Discount{appliedPromo ? ` (${appliedPromo.code})` : ''}
            </Text>
            <Text style={styles.discountValue}>-${cart.discount.toFixed(2)}</Text>
          </View>
        ) : null}
        <View style={styles.totalContainer}>
          <Text style={styles.totalLabel}>Total:</Text>
          <Text style={styles.totalAmount}>${cart.total.toFixed(2)}</Text>
        </View>
        <Button
          title="Checkout"
          onPress={handleCheckout}
          loading={checkoutLoading}
        />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  list: {
    padding: 16,
    // Leaves room for the taller footer (subtotal, discount, total and checkout).
    paddingBottom: 220,
  },
  center: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  message: {
    fontSize: 16,
    color: '#666',
    marginBottom: 16,
    textAlign: 'center',
  },
  emptyText: {
    fontSize: 18,
    color: '#666',
    marginBottom: 16,
  },
  footer: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    backgroundColor: '#fff',
    padding: 16,
    borderTopWidth: 1,
    borderTopColor: '#e0e0e0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: -2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 5,
  },
  totalContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  breakdownRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  breakdownLabel: {
    fontSize: 15,
    color: '#666',
  },
  breakdownValue: {
    fontSize: 15,
    color: '#333',
  },
  discountLabel: {
    fontSize: 15,
    color: '#34C759',
  },
  discountValue: {
    fontSize: 15,
    fontWeight: '600',
    color: '#34C759',
  },
  promoContainer: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 12,
    marginBottom: 12,
  },
  promoTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  promoRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  promoInput: {
    flex: 1,
    borderWidth: 1,
    borderColor: '#ccc',
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
    marginRight: 8,
  },
  promoButton: {
    backgroundColor: '#007AFF',
    borderRadius: 6,
    paddingVertical: 11,
    paddingHorizontal: 16,
    minWidth: 84,
    alignItems: 'center',
  },
  promoButtonDisabled: {
    opacity: 0.6,
  },
  promoButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  promoError: {
    color: '#FF3B30',
    fontSize: 14,
    marginTop: 8,
  },
  appliedRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 10,
  },
  appliedText: {
    fontSize: 14,
    color: '#333',
  },
  appliedCode: {
    fontWeight: '700',
  },
  removeText: {
    fontSize: 14,
    color: '#FF3B30',
  },
  totalLabel: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
  },
  totalAmount: {
    fontSize: 24,
    fontWeight: '700',
    color: '#007AFF',
  },
});

