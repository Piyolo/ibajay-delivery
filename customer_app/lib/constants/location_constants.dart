/// Reference location used as a fallback map center / distance origin before
/// the customer has saved a real address, and as the default pin location in
/// the Location Setup screen's map mockup.
class LocationConstants {
  LocationConstants._();

  // Ibajay, Aklan town center.
  static const double townLat = 11.5459;
  static const double townLng = 122.2039;

  /// All barangays of Ibajay, Aklan — the municipality the platform serves.
  /// Vendors pick which of these they deliver to; customers pick which one
  /// their address is in.
  static const List<String> ibajayBarangays = [
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
}
