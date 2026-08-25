import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/order.dart';
import '../../providers/cart_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/vendor_provider.dart';
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
  FulfillmentType _fulfillment = FulfillmentType.delivery;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  DateTime? _scheduledFor;
  final _instructionsController = TextEditingController();
  bool _placing = false;

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
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

  Future<void> _placeOrder() async {
    final cartProvider = context.read<CartProvider>();
    final cart = cartProvider.cart;
    final vendor = context.read<VendorProvider>().vendorById(cart.vendorId!);
    if (vendor == null) return;

    final location = context.read<LocationProvider>();
    if (_fulfillment != FulfillmentType.pickup && location.activeAddress == null) {
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
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final order = context.read<OrderProvider>().placeOrder(
          cart: cart,
          vendor: vendor,
          fulfillmentType: _fulfillment,
          paymentMethod: _payment,
          deliveryAddress: location.activeAddress?.fullAddress ?? '',
          destinationLat: location.activeAddress?.latitude,
          destinationLng: location.activeAddress?.longitude,
          scheduledFor: _scheduledFor,
        );

    cartProvider.clear();
    setState(() => _placing = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderTrackingScreen(orderId: order.id)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>().cart;
    final vendor = context.watch<VendorProvider>().vendorById(cart.vendorId ?? '');
    final location = context.watch<LocationProvider>();

    if (vendor == null) {
      return const Scaffold(body: Center(child: Text('Your cart is empty')));
    }

    final settings = vendor.deliverySettings;
    final deliveryFee = _fulfillment == FulfillmentType.pickup ? 0.0 : settings.baseDeliveryFee;
    final total = cart.subtotal + deliveryFee;

    final fulfillmentTiles = <Widget>[
      if (settings.deliveryEnabled)
        RadioListTile<FulfillmentType>(
          value: FulfillmentType.delivery,
          title: const Text('Delivery'),
          subtitle: Text(
              '₱${settings.baseDeliveryFee.toStringAsFixed(0)} delivery fee · ${settings.estimatedPrepMinutes} min prep'),
          contentPadding: EdgeInsets.zero,
        ),
      if (settings.pickupEnabled)
        const RadioListTile<FulfillmentType>(
          value: FulfillmentType.pickup,
          title: Text('Pickup'),
          subtitle: Text('No delivery fee — pick up at the store'),
          contentPadding: EdgeInsets.zero,
        ),
      if (settings.scheduledDeliveryEnabled)
        const RadioListTile<FulfillmentType>(
          value: FulfillmentType.scheduled,
          title: Text('Scheduled Delivery'),
          subtitle: Text('Choose a future date and time'),
          contentPadding: EdgeInsets.zero,
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(title: 'Delivery Method'),
            RadioGroup<FulfillmentType>(
              groupValue: _fulfillment,
              onChanged: (v) => setState(() => _fulfillment = v!),
              child: Column(children: fulfillmentTiles),
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
              onChanged: (v) => setState(() => _payment = v!),
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
                    _summaryRow('Delivery Fee', deliveryFee),
                    const Divider(),
                    _summaryRow('Total', total, bold: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryButton(
            label: 'Place Order · ₱${total.toStringAsFixed(0)}',
            loading: _placing,
            onPressed: _placeOrder,
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text('₱${value.toStringAsFixed(0)}',
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
