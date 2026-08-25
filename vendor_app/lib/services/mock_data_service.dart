import '../models/vendor.dart';
import '../models/food_item.dart';
import '../models/order.dart';

/// Stand-in for real API calls (FastAPI + PostgreSQL) so every screen is
/// fully browsable today. Swap the bodies of these methods for `http`/
/// WebSocket calls once the backend from the spec is live — the models
/// and provider layer above this don't need to change.
class MockDataService {
  static VendorProfile buildVendor() {
    return VendorProfile(
      id: 'vendor_1',
      ownerName: 'Maria Santos',
      storeName: "Maria's Kitchen",
      description: 'Home-style Filipino comfort food, cooked fresh daily.',
      mobileNumber: '09171234567',
      email: 'maria@example.com',
      address: '12 Rizal St, Barangay Poblacion, Iloilo City',
      latitude: 10.7202,
      longitude: 122.5621,
      categories: ['Meals', 'Fast Food'],
      status: StoreStatus.open,
      isVerified: true,
      rating: 4.8,
      totalReviews: 214,
    );
  }

  static List<FoodItem> buildMenu() {
    return [
      FoodItem(
        id: 'f1',
        name: 'Chicken Adobo Rice Bowl',
        description: 'Classic soy-vinegar braised chicken over steamed rice.',
        price: 129,
        category: 'Meals',
        isAvailable: true,
        totalSold: 342,
        addons: [
          FoodAddon(name: 'Extra Rice', price: 20),
          FoodAddon(name: 'Fried Egg', price: 25),
        ],
      ),
      FoodItem(
        id: 'f2',
        name: 'Crispy Pork Sisig',
        description: 'Sizzling chopped pork, calamansi, and chili.',
        price: 159,
        category: 'Meals',
        isAvailable: true,
        totalSold: 198,
      ),
      FoodItem(
        id: 'f3',
        name: 'Classic Beef Burger',
        description: 'Grilled beef patty, cheddar, lettuce, house sauce.',
        price: 149,
        category: 'Fast Food',
        isAvailable: true,
        totalSold: 275,
        addons: [
          FoodAddon(name: 'Add Cheese', price: 20),
          FoodAddon(name: 'Add Bacon', price: 30),
        ],
      ),
      FoodItem(
        id: 'f4',
        name: 'Halo-Halo',
        description: 'Shaved ice, mixed fruits, ube, leche flan.',
        price: 99,
        category: 'Desserts',
        isAvailable: false,
        totalSold: 120,
      ),
      FoodItem(
        id: 'f5',
        name: 'Iced Calamansi Juice',
        description: 'Fresh-squeezed, lightly sweetened.',
        price: 49,
        category: 'Drinks',
        isAvailable: true,
        totalSold: 410,
      ),
    ];
  }

  static List<VendorOrder> buildOrders() {
    final now = DateTime.now();
    return [
      VendorOrder(
        id: 'ORD-1042',
        customerName: 'Juan Dela Cruz',
        customerMobile: '09123456789',
        deliveryAddress: '45 Mabini St, Iloilo City',
        items: [
          OrderLineItem(foodName: 'Chicken Adobo Rice Bowl', quantity: 2, price: 129, addons: ['Fried Egg']),
          OrderLineItem(foodName: 'Iced Calamansi Juice', quantity: 2, price: 49),
        ],
        status: OrderStatus.pending,
        fulfillmentType: FulfillmentType.delivery,
        notes: 'Please knock instead of ringing the doorbell — baby sleeping.',
        placedAt: now.subtract(const Duration(minutes: 3)),
        deliveryFee: 35,
      ),
      VendorOrder(
        id: 'ORD-1041',
        customerName: 'Angela Reyes',
        customerMobile: '09981234567',
        deliveryAddress: 'Pickup at store',
        items: [
          OrderLineItem(foodName: 'Classic Beef Burger', quantity: 1, price: 149, addons: ['Add Cheese', 'Add Bacon']),
        ],
        status: OrderStatus.preparing,
        fulfillmentType: FulfillmentType.pickup,
        placedAt: now.subtract(const Duration(minutes: 18)),
      ),
      VendorOrder(
        id: 'ORD-1040',
        customerName: 'Mark Villanueva',
        customerMobile: '09051239876',
        deliveryAddress: '9 Luna St, Iloilo City',
        items: [
          OrderLineItem(foodName: 'Crispy Pork Sisig', quantity: 1, price: 159, specialInstructions: 'Extra spicy'),
        ],
        status: OrderStatus.outForDelivery,
        fulfillmentType: FulfillmentType.delivery,
        placedAt: now.subtract(const Duration(minutes: 40)),
        deliveryFee: 40,
      ),
      VendorOrder(
        id: 'ORD-1039',
        customerName: 'Liza Gomez',
        customerMobile: '09221230098',
        deliveryAddress: '77 Quezon Ave, Iloilo City',
        items: [
          OrderLineItem(foodName: 'Chicken Adobo Rice Bowl', quantity: 1, price: 129),
        ],
        status: OrderStatus.accepted,
        fulfillmentType: FulfillmentType.scheduled,
        placedAt: now.subtract(const Duration(hours: 2)),
        scheduledFor: now.add(const Duration(hours: 3)),
        deliveryFee: 35,
      ),
      VendorOrder(
        id: 'ORD-1035',
        customerName: 'Ramon Cruz',
        customerMobile: '09330001122',
        deliveryAddress: '3 Burgos St, Iloilo City',
        items: [
          OrderLineItem(foodName: 'Halo-Halo', quantity: 3, price: 99),
        ],
        status: OrderStatus.completed,
        fulfillmentType: FulfillmentType.delivery,
        placedAt: now.subtract(const Duration(days: 1, hours: 2)),
        deliveryFee: 35,
      ),
    ];
  }
}