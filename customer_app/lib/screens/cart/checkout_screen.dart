import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../models/vendor.dart';
import '../../providers/cart_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../orders/order_tracking_screen.dart';
import '../settings/addresses_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  FulfillmentType? _fulfillment;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  DateTime? _scheduledFor;
  final _instructionsController = TextEditingController();
  final _promoController = TextEditingController();
  bool _placing = false;
  bool _checkingPromo = false;

  /// Promo validated against the backend: code + applied discount.
  String? _appliedPromoCode;
  double _promoDiscount = 0;
  String? _promoError;

  @override
  void dispose() {
    _instructionsController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  /// Picks the first fulfillment method the vendor actually offers and the
  /// matching payment method, so the radio group never starts out with a
  /// selection that matches no visible tile.
  void _ensureDefaults(DeliverySettings settings) {
    if (_fulfillment != null &&
        ((_fulfillment == FulfillmentType.delivery && settings.deliveryEnabled) ||
            (_fulfillment == FulfillmentType.pickup && settings.pickupEnabled) ||
            (_fulfillment == FulfillmentType.scheduled && settings.scheduledDeliveryEnabled))) {
      return;
    }
    if (settings.deliveryEnabled) {
      _fulfillment = FulfillmentType.delivery;
    } else if (settings.pickupEnabled) {
      _fulfillment = FulfillmentType.pickup;
    } else if (settings.scheduledDeliveryEnabled) {
      _fulfillment = FulfillmentType.scheduled;
    }
    _syncPaymentWithFulfillment();
  }

  // Delivery can only be paid COD; pickup only cash-on-pickup — keep the
  // two radio groups consistent instead of allowing an impossible pair.
  void _syncPaymentWithFulfillment() {
    _payment = _fulfillment == FulfillmentType.pickup
        ? PaymentMethod.cashOnPickup
        : PaymentMethod.cashOnDelivery;
  }

  Future<void> _pickScheduleTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time == null || !mounted) return;
    setState(() {
      _scheduledFor = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  /// Validates the promo code against the backend and shows the discount.
  Future<void> _applyPromo(VendorProfile vendor, double subtotal) async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _checkingPromo = true;
      _promoError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final discount = await context
          .read<OrderProvider>()
          .validatePromo(vendor: vendor, code: code, subtotal: subtotal);
      if (!mounted) return;
      setState(() {
        _appliedPromoCode = code.toUpperCase();
        _promoDiscount = discount;
      });
      messenger.showSnackBar(SnackBar(content: Text('Promo applied — ₱${discount.toStringAsFixed(0)} off')));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _promoError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _promoError = 'Could not check that code — try again');
    }
    if (mounted) setState(() => _checkingPromo = false);
  }

  void _removePromo() {
    setState(() {
      _appliedPromoCode = null;
      _promoDiscount = 0;
      _promoController.clear();
      _promoError = null;
    });
  }

  Future<void> _placeOrder() async {
    final cartProvider = context.read<CartProvider>();
    final cart = cartProvider.cart;
    if (cart.isEmpty || cart.vendorId == null) return;

    final vendor = context.read<VendorProvider>().vendorById(cart.vendorId!);
    final address = context.read<LocationProvider>().activeAddress;
    if (vendor == null || _fulfillment == null) return;

    if (_fulfillment != FulfillmentType.pickup && address == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a delivery address first')),
      );
      return;
    }
    if (_fulfillment == FulfillmentType.scheduled && _scheduledFor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a date and time')),
      );
      return;
    }

    setState(() => _placing = true);
    final orderProvider = context.read<OrderProvider>();
    CustomerOrder? order;
    String? errorMessage;
    try {
      order = await orderProvider.checkout(
        cart: cart,
        vendor: vendor,
        fulfillmentType: _fulfillment!,
        paymentMethod: _payment,
        addressId: address?.id ?? '',
        deliveryInstructions: _instructionsController.text,
        scheduledFor: _scheduledFor,
        promoCode: _appliedPromoCode,
      );
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Could not place your order. Please try again.';
    }
    if (!mounted) return;
    setState(() => _placing = false);

    final placed = order;
    if (placed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage ?? 'Could not place your order')),
      );
      return;
    }

    cartProvider.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: placed.id)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>().cart;
    final vendor = context.watch<VendorProvider>().vendorById(cart.vendorId ?? '');
    final location = context.watch<LocationProvider>();

    if (vendor == null || cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: 'Your cart is empty',
          subtitle: 'Add items from a store to check out.',
          action: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Browse stores'),
          ),
        ),
      );
    }

    final settings = vendor.deliverySettings;
    _ensureDefaults(settings);
    final deliveryFee =
        _fulfillment == FulfillmentType.pickup ? 0.0 : settings.baseDeliveryFee;
    final promoDiscount =
        _appliedPromoCode == null ? 0.0 : _promoDiscount.clamp(0.0, cart.subtotal);
    final total = (cart.subtotal + deliveryFee - promoDiscount)
        .clamp(0.0, double.infinity);

    Widget fulfillmentTile(FulfillmentType value, String title, String subtitle) {
      return RadioListTile<FulfillmentType>(
        value: value,
        title: Text(title),
        subtitle: Text(subtitle),
        contentPadding: EdgeInsets.zero,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Fulfillment Method'),
            RadioGroup<FulfillmentType>(
              groupValue: _fulfillment,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _fulfillment = v;
                  _syncPaymentWithFulfillment();
                });
              },
              child: Column(
                children: [
                  if (settings.deliveryEnabled)
                    fulfillmentTile(
                      FulfillmentType.delivery,
                      'Delivery',
                      '₱${settings.baseDeliveryFee.toStringAsFixed(0)} base fee · ${settings.estimatedPrepMinutes} min prep',
                    ),
                  if (settings.pickupEnabled)
                    fulfillmentTile(
                      FulfillmentType.pickup,
                      'Pickup',
                      'No delivery fee — pick up at the store',
                    ),
                  if (settings.scheduledDeliveryEnabled)
                    fulfillmentTile(
                      FulfillmentType.scheduled,
                      'Scheduled Delivery',
                      'Choose a future date and time',
                    ),
                ],
              ),
            ),
            if (_fulfillment == FulfillmentType.scheduled) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickScheduleTime,
                icon: const Icon(Icons.schedule),
                label: Text(_scheduledFor == null
                    ? 'Choose Date & Time'
                    : '${_scheduledFor!.month}/${_scheduledFor!.day} at ${TimeOfDay.fromDateTime(_scheduledFor!).format(context)}'),
              ),
            ],
            const SizedBox(height: 20),
            if (_fulfillment != FulfillmentType.pickup) ...[
              const SectionHeader(title: 'Delivery Address'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on, color: AppColors.primary),
                  title: Text(location.activeAddress?.label ?? 'No address saved'),
                  subtitle: Text(location.activeAddress?.fullAddress ?? 'Add a delivery address to continue'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddressesScreen())),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              const SectionHeader(title: 'Pickup Location'),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.storefront, color: AppColors.primary),
                  title: Text(vendor.storeName),
                  subtitle: Text(vendor.address),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const SectionHeader(title: 'Payment Method'),
            RadioGroup<PaymentMethod>(
              groupValue: _payment,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _payment = v);
              },
              child: Column(
                children: [
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.cashOnDelivery,
                    enabled: _fulfillment != FulfillmentType.pickup,
                    title: const Text('Cash on Delivery'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<PaymentMethod>(
                    value: PaymentMethod.cashOnPickup,
                    enabled: _fulfillment == FulfillmentType.pickup,
                    title: const Text('Cash on Pickup'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Order Summary'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ...cart.items.map((i) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Text('${i.quantity}x ', style: const TextStyle(color: AppColors.textSecondary)),
                              Expanded(child: Text(i.foodItem.name)),
                              Text('₱${i.lineTotal.toStringAsFixed(0)}'),
                            ],
                          ),
                        )),
                    const Divider(),
                    _summaryRow('Subtotal', cart.subtotal),
                    _summaryRow('Delivery Fee (estimate)', deliveryFee),
                    if (_appliedPromoCode != null) ...[
                      _summaryRow('Promo ($_appliedPromoCode)', -promoDiscount),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _removePromo,
                          child: const Text('Remove', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    const Divider(),
                    _summaryRow('Total', total, bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Promo code entry — validated by the backend before ordering.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoController,
                    textCapitalization: TextCapitalization.characters,
                    enabled: _appliedPromoCode == null && !_checkingPromo,
                    decoration: InputDecoration(
                      hintText: 'Promo code',
                      errorText: _promoError,
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _promoError = null),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: (_appliedPromoCode != null || _checkingPromo || cart.isEmpty)
                      ? null
                      : () => _applyPromo(vendor, cart.subtotal),
                  child: _checkingPromo
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _instructionsController,
              decoration: const InputDecoration(
                labelText: 'Delivery instructions (optional)',
                hintText: 'e.g. Landmark, gate color, etc.',
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: location.activeAddress == null && _fulfillment != FulfillmentType.pickup
                ? 'Add a delivery address to continue'
                : 'Place Order · ₱${total.toStringAsFixed(0)}',
            loading: _placing,
            onPressed: _placeOrder,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    final sign = value < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text('$sign₱${value.abs().toStringAsFixed(0)}',
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: value < 0 ? AppColors.success : null,
              )),
        ],
      ),
    );
  }
}
