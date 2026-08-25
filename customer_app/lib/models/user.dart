class AppUser {
  final String id;
  String fullName;
  String mobileNumber;
  String email;

  AppUser({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'mobileNumber': mobileNumber,
        'email': email,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );
}

class SavedAddress {
  final String id;
  String label; // Home, Work, Other
  String fullAddress;
  String barangay; // one of LocationConstants.ibajayBarangays
  double latitude;
  double longitude;
  String landmark;
  bool isDefault;

  SavedAddress({
    required this.id,
    this.label = 'Home',
    required this.fullAddress,
    this.barangay = 'Poblacion',
    required this.latitude,
    required this.longitude,
    this.landmark = '',
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'fullAddress': fullAddress,
        'barangay': barangay,
        'latitude': latitude,
        'longitude': longitude,
        'landmark': landmark,
        'isDefault': isDefault,
      };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Home',
        fullAddress: json['fullAddress'] as String? ?? '',
        barangay: json['barangay'] as String? ?? 'Poblacion',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        landmark: json['landmark'] as String? ?? '',
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
