import 'dart:math' as math;

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

  static const _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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

  /// Builds the app's full 7-day list from the backend's hour rows
  /// (day_of_week 0=Monday .. 6=Sunday). Missing days default to closed.
  static List<OperatingHours> fromApiRows(List<dynamic> rows) {
    final byDay = {
      for (final row in rows)
        (row as Map<String, dynamic>)['day_of_week'] as int: row,
    };
    return List.generate(7, (i) {
      final row = byDay[i];
      if (row == null) {
        return OperatingHours(day: _dayNames[i], isOpen: false);
      }
      return OperatingHours(
        day: _dayNames[i],
        isOpen: !(row['is_closed_all_day'] as bool? ?? false),
        openTime: (row['open_time'] as String? ?? '08:00').substring(0, 5),
        closeTime: (row['close_time'] as String? ?? '20:00').substring(0, 5),
      );
    });
  }

  /// Backend payload shape for this day row.
  Map<String, dynamic> toApi(int dayOfWeek) => {
        'day_of_week': dayOfWeek,
        'open_time': openTime,
        'close_time': closeTime,
        'is_closed_all_day': !isOpen,
      };

  static List<OperatingHours> defaultWeek() =>
      _dayNames.map((d) => OperatingHours(day: d)).toList();
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

  /// Maps the backend's nested `delivery` object (snake_case) from
  /// GET/PUT /vendor/me.
  factory DeliverySettings.fromApi(Map<String, dynamic> json) => DeliverySettings(
        deliveryEnabled: json['delivery_enabled'] as bool? ?? true,
        pickupEnabled: json['pickup_enabled'] as bool? ?? true,
        scheduledDeliveryEnabled: json['scheduled_delivery_enabled'] as bool? ?? false,
        deliveryBarangays: (json['delivery_barangays'] as List?)
                ?.cast<String>()
                .where((b) => kIbajayBarangays.contains(b))
                .toList() ??
            [],
        baseDeliveryFee: (json['base_delivery_fee'] as num?)?.toDouble() ?? 30,
      );

  /// Backend payload shape for PUT /vendor/me/delivery-settings.
  Map<String, dynamic> toApi() => {
        'delivery_enabled': deliveryEnabled,
        'pickup_enabled': pickupEnabled,
        'scheduled_delivery_enabled': scheduledDeliveryEnabled,
        'delivery_barangays': deliveryBarangays,
        'base_delivery_fee': baseDeliveryFee,
      };
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

  /// Maps GET/PUT /vendor/me (snake_case) onto the app model.
  ///
  /// Status derivation: the backend tracks two booleans (open/paused);
  /// `paused` wins, then open/closed. The app's "busy" state maps to
  /// open on the backend.
  factory VendorProfile.fromApi(Map<String, dynamic> json) {
    final isPaused = json['is_paused'] as bool? ?? false;
    final isOpen = json['is_open'] as bool? ?? false;
    final status = isPaused
        ? StoreStatus.paused
        : isOpen
            ? StoreStatus.open
            : StoreStatus.closed;
    return VendorProfile(
      id: json['id'] as String,
      ownerName: json['owner_name'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mobileNumber: json['contact_number'] as String? ?? '',
      email: json['owner_email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      logoUrl: json['logo_url'] as String? ?? '',
      bannerUrl: json['banner_url'] as String? ?? '',
      categories: (json['categories'] as List?)?.cast<String>().toList() ?? [],
      status: status,
      isVerified: json['is_verified'] as bool? ?? false,
      rating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      operatingHours: json['hours'] != null
          ? OperatingHours.fromApiRows(json['hours'] as List)
          : OperatingHours.defaultWeek(),
      deliverySettings: json['delivery'] != null
          ? DeliverySettings.fromApi(json['delivery'] as Map<String, dynamic>)
          : DeliverySettings(),
    );
  }
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

/// Ibajay town proper + generous municipality radius — used by the
/// store-setup map picker to detect pins placed outside the service area.
/// Source: Ibajay municipal hall ≈ 11°49′16″N 122°09′42″E.
const double kIbajayTownLat = 11.8211;
const double kIbajayTownLng = 122.1617;
const double kIbajayServiceRadiusKm = 15.0;

/// Neighboring municipalities — a reverse-geocoded pick matching one of
/// these is outside Ibajay even when it slips inside the radius.
const List<String> kNeighboringMunicipalities = [
  'nabas',
  'pandan',
  'buruanga',
  'malay',
  'tangalan',
  'makato',
  'altavas',
  'banga',
  'kalibo',
  'numancia',
  'lezo',
  'malinao',
  'libacao',
  'madalag',
  'batan',
  'balete',
  'new washington',
];

/// True when [lat]/[lng] is plausibly inside the served municipality.
bool isInsideIbajay(double lat, double lng) {
  const r = 6371.0;
  final dLat = (lat - kIbajayTownLat) * (math.pi / 180);
  final dLng = (lng - kIbajayTownLng) * (math.pi / 180);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(kIbajayTownLat * math.pi / 180) *
          math.cos(lat * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)) <=
      kIbajayServiceRadiusKm;
}

/// Official barangay census centroids (PhilAtlas, Aug 2026) — used by the
/// map picker to sanity-check reverse-geocoded barangay labels.
const Map<String, List<double>> kBarangayCenters = {
  'Agbago': [11.8088, 122.1464],
  'Agdugayan': [11.7693, 122.1594],
  'Antipolo': [11.8021, 122.1226],
  'Aparicio': [11.6950, 122.1879],
  'Aquino': [11.8185, 122.1104],
  'Aslum': [11.8239, 122.1560],
  'Bagacay': [11.7919, 122.1659],
  'Batuan': [11.7917, 122.1506],
  'Buenavista': [11.8014, 122.1803],
  'Bugtongbato': [11.8061, 122.2094],
  'Cabugao': [11.7432, 122.1919],
  'Capilijan': [11.7889, 122.1571],
  'Colongcolong': [11.8188, 122.1732],
  'Laguinbanua': [11.8082, 122.1580],
  'Mabusao': [11.7726, 122.1286],
  'Malindog': [11.7015, 122.1808],
  'Maloco': [11.7842, 122.1526],
  'Mina-a': [11.6669, 122.1927],
  'Monlaque': [11.7104, 122.1832],
  'Naile': [11.7666, 122.1765],
  'Naisud': [11.8055, 122.1941],
  'Naligusan': [11.7752, 122.1733],
  'Ondoy': [11.8193, 122.1227],
  'Poblacion': [11.8188, 122.1607],
  'Polo': [11.8177, 122.1652],
  'Regador': [11.7801, 122.2020],
  'Rivera': [11.7313, 122.2016],
  'Rizal': [11.7813, 122.1724],
  'San Isidro': [11.8119, 122.1796],
  'San Jose': [11.7406, 122.1770],
  'Santa Cruz': [11.7931, 122.1411],
  'Tagbaya': [11.8161, 122.1298],
  'Tul-ang': [11.8085, 122.1675],
  'Unat': [11.7808, 122.1647],
};

/// Haversine distance in km between two lat/lng pairs.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * (math.pi / 180);
  final dLng = (lng2 - lng1) * (math.pi / 180);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Nearest known barangay center to [lat]/[lng] and its distance.
MapEntry<String, double> nearestBarangayTo(double lat, double lng) {
  String bestName = '';
  var bestKm = double.infinity;
  kBarangayCenters.forEach((name, c) {
    final d = haversineKm(lat, lng, c[0], c[1]);
    if (d < bestKm) {
      bestKm = d;
      bestName = name;
    }
  });
  return MapEntry(bestName, bestKm);
}

/// Matches a free-text place name to one of Ibajay's barangays,
/// case/space/hyphen-insensitive. Null when nothing matches.
String? matchIbajayBarangay(String name) {
  final n = _normalizePlace(name);
  if (n.isEmpty) return null;
  for (final b in kIbajayBarangays) {
    final key = _normalizePlace(b);
    if (n == key || n.contains(key) || key.contains(n)) return b;
  }
  return null;
}

/// Barangays whose names start with or contain [query], in list order —
/// drives the setup screen's type-ahead ("a" -> Agbago, Aquino, Aslum…).
List<String> suggestIbajayBarangays(String query) {
  final q = _normalizePlace(query);
  if (q.isEmpty) return const [];
  final starts = <String>[];
  final contains = <String>[];
  for (final b in kIbajayBarangays) {
    final key = _normalizePlace(b);
    if (key.startsWith(q)) {
      starts.add(b);
    } else if (key.contains(q)) {
      contains.add(b);
    }
  }
  return [...starts, ...contains];
}

/// Approximate center of a barangay (null when unknown).
List<double>? barangayCenter(String barangay) => kBarangayCenters[barangay];

String _normalizePlace(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');