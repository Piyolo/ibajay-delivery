enum StoreStatus { open, busy, paused, closed }

extension StoreStatusX on StoreStatus {
  String get label {
    switch (this) {
      case StoreStatus.open:
        return 'Open';
      case StoreStatus.busy:
        return 'Busy';
      case StoreStatus.paused:
        return 'Paused';
      case StoreStatus.closed:
        return 'Closed';
    }
  }

  String get description {
    switch (this) {
      case StoreStatus.open:
        return 'Accepting orders normally';
      case StoreStatus.busy:
        return 'Accepting orders, but expect delays';
      case StoreStatus.paused:
        return 'Temporarily not accepting new orders';
      case StoreStatus.closed:
        return 'Not accepting orders';
    }
  }

  /// Whether a customer could place a new order right now.
  bool get acceptsOrders => this == StoreStatus.open || this == StoreStatus.busy;
}

class OperatingHours {
  final String day; // "Monday", "Tuesday", ...
  bool isOpen;
  String openTime; // "08:00"
  String closeTime; // "20:00"

  OperatingHours({
    required this.day,
    this.isOpen = true,
    this.openTime = '08:00',
    this.closeTime = '20:00',
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'isOpen': isOpen,
        'openTime': openTime,
        'closeTime': closeTime,
      };

  factory OperatingHours.fromJson(Map<String, dynamic> json) => OperatingHours(
        day: json['day'] as String,
        isOpen: json['isOpen'] as bool? ?? true,
        openTime: json['openTime'] as String? ?? '08:00',
        closeTime: json['closeTime'] as String? ?? '20:00',
      );

  static List<OperatingHours> defaultWeek() => [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ].map((d) => OperatingHours(day: d)).toList();
}

class DeliverySettings {
  bool deliveryEnabled;
  bool pickupEnabled;
  bool scheduledDeliveryEnabled;

  /// Barangays (of Ibajay, Aklan) this vendor delivers to. Delivery is
  /// municipality-scoped, so coverage is picked per barangay rather than
  /// by radius.
  List<String> deliveryBarangays;
  double baseDeliveryFee;

  DeliverySettings({
    this.deliveryEnabled = true,
    this.pickupEnabled = true,
    this.scheduledDeliveryEnabled = false,
    List<String>? deliveryBarangays,
    this.baseDeliveryFee = 30,
  }) : deliveryBarangays = deliveryBarangays ?? ['Poblacion'];

  Map<String, dynamic> toJson() => {
        'deliveryEnabled': deliveryEnabled,
        'pickupEnabled': pickupEnabled,
        'scheduledDeliveryEnabled': scheduledDeliveryEnabled,
        'deliveryBarangays': deliveryBarangays,
        'baseDeliveryFee': baseDeliveryFee,
      };

  factory DeliverySettings.fromJson(Map<String, dynamic> json) => DeliverySettings(
        deliveryEnabled: json['deliveryEnabled'] as bool? ?? true,
        pickupEnabled: json['pickupEnabled'] as bool? ?? true,
        scheduledDeliveryEnabled: json['scheduledDeliveryEnabled'] as bool? ?? false,
        deliveryBarangays: (json['deliveryBarangays'] as List?)
                ?.cast<String>()
                .where((b) => kIbajayBarangays.contains(b))
                .toList() ??
            ['Poblacion'],
        baseDeliveryFee: (json['baseDeliveryFee'] as num?)?.toDouble() ?? 30,
      );
}

class VendorProfile {
  final String id;
  String ownerName;
  String storeName;
  String description;
  String mobileNumber;
  String email;
  String address;
  double? latitude;
  double? longitude;
  String logoUrl;
  String bannerUrl;
  List<String> categories;
  StoreStatus status;
  bool isVerified;
  double rating;
  int totalReviews;
  List<OperatingHours> operatingHours;
  DeliverySettings deliverySettings;

  /// Convenience accessor used by quick-toggle UI (header pill, etc).
  bool get isOpen => status == StoreStatus.open;

  VendorProfile({
    required this.id,
    required this.ownerName,
    required this.storeName,
    this.description = '',
    required this.mobileNumber,
    required this.email,
    this.address = '',
    this.latitude,
    this.longitude,
    this.logoUrl = '',
    this.bannerUrl = '',
    List<String>? categories,
    this.status = StoreStatus.open,
    this.isVerified = false,
    this.rating = 0,
    this.totalReviews = 0,
    List<OperatingHours>? operatingHours,
    DeliverySettings? deliverySettings,
  })  : categories = categories ?? [],
        operatingHours = operatingHours ?? OperatingHours.defaultWeek(),
        deliverySettings = deliverySettings ?? DeliverySettings();

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerName': ownerName,
        'storeName': storeName,
        'description': description,
        'mobileNumber': mobileNumber,
        'email': email,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'logoUrl': logoUrl,
        'bannerUrl': bannerUrl,
        'categories': categories,
        'status': status.name,
        'isVerified': isVerified,
        'rating': rating,
        'totalReviews': totalReviews,
        'operatingHours': operatingHours.map((h) => h.toJson()).toList(),
        'deliverySettings': deliverySettings.toJson(),
      };

  factory VendorProfile.fromJson(Map<String, dynamic> json) => VendorProfile(
        id: json['id'] as String,
        ownerName: json['ownerName'] as String? ?? '',
        storeName: json['storeName'] as String? ?? '',
        description: json['description'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
        email: json['email'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        logoUrl: json['logoUrl'] as String? ?? '',
        bannerUrl: json['bannerUrl'] as String? ?? '',
        categories: (json['categories'] as List?)?.cast<String>().toList() ?? [],
        status: StoreStatus.values.firstWhere(
          (s) => s.name == (json['status'] as String?),
          orElse: () => StoreStatus.open,
        ),
        isVerified: json['isVerified'] as bool? ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        totalReviews: json['totalReviews'] as int? ?? 0,
        operatingHours: (json['operatingHours'] as List?)
                ?.map((h) => OperatingHours.fromJson(h as Map<String, dynamic>))
                .toList() ??
            OperatingHours.defaultWeek(),
        deliverySettings: json['deliverySettings'] != null
            ? DeliverySettings.fromJson(json['deliverySettings'] as Map<String, dynamic>)
            : DeliverySettings(),
      );
}

const List<String> kStoreCategoryOptions = [
  'Fast Food',
  'Drinks',
  'Desserts',
  'Bakery',
  'Grocery',
  'Meals',
  'Coffee',
  'Snacks',
];

/// All barangays of Ibajay, Aklan — the municipality the platform serves.
/// Vendors pick which of these they can deliver to (municipality-scoped
/// delivery, so no radius needed).
const List<String> kIbajayBarangays = [
  'Agbago',
  'Agdugayan',
  'Antipolo',
  'Aparicio',
  'Aquino',
  'Aslum',
  'Bagacay',
  'Batuan',
  'Buenavista',
  'Bugtongbato',
  'Cabugao',
  'Capilijan',
  'Colongcolong',
  'Laguinbanua',
  'Mabusao',
  'Malindog',
  'Maloco',
  'Mina-a',
  'Monlaque',
  'Naile',
  'Naisud',
  'Naligusan',
  'Ondoy',
  'Poblacion',
  'Polo',
  'Regador',
  'Rivera',
  'Rizal',
  'San Isidro',
  'San Jose',
  'Santa Cruz',
  'Tagbaya',
  'Tul-ang',
  'Unat',
];