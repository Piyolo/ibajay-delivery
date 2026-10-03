/// Reference location used as a fallback map center / distance origin before
/// the customer has saved a real address.
library;

import 'dart:math' as math;

class LocationConstants {
  LocationConstants._();

  // Ibajay, Aklan town proper (municipal hall area).
  // Source: 11°49′16″N 122°09′42″E
  static const double townLat = 11.8211;
  static const double townLng = 122.1617;

  /// Generous radius (km) around the town center covering ALL of the
  /// municipality's 35 barangays (the municipality is ~159 km² and
  /// stretches well beyond the poblacion). Anything beyond this AND not
  /// identified as Ibajay by reverse geocoding counts as outside the
  /// service area.
  static const double serviceRadiusKm = 15.0;

  /// Neighboring municipalities — a pick whose reverse-geocoded
  /// municipality matches one of these is outside Ibajay even when it
  /// slips inside the radius.
  static const List<String> neighboringMunicipalities = [
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
  /// Coarse distance check; the map picker additionally cross-checks the
  /// reverse-geocoded municipality name.
  static bool isInServiceArea(double lat, double lng) {
    return haversineKm(townLat, townLng, lat, lng) <= serviceRadiusKm;
  }

  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
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

  /// Matches a free-text place name to one of Ibajay's barangays,
  /// case/space/hyphen-insensitive ("tul ang" -> "Tul-ang"). Empty when no
  /// reasonable match exists.
  static String? matchBarangay(String name) {
    final n = _normalizePlace(name);
    if (n.isEmpty) return null;
    for (final b in ibajayBarangays) {
      final key = _normalizePlace(b);
      if (n == key || n.contains(key) || key.contains(n)) return b;
    }
    return null;
  }

  /// Barangay list entries that start with or contain [query], in list
  /// order — drives search suggestions ("a" -> Agbago, Aquino, Aslum…).
  static List<String> suggestBarangays(String query) {
    final q = _normalizePlace(query);
    if (q.isEmpty) return const [];
    final starts = <String>[];
    final contains = <String>[];
    for (final b in ibajayBarangays) {
      final key = _normalizePlace(b);
      if (key.startsWith(q)) {
        starts.add(b);
      } else if (key.contains(q)) {
        contains.add(b);
      }
    }
    return [...starts, ...contains];
  }

  static String _normalizePlace(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');

  /// Approximate centers per barangay — official census centroids from
  /// PhilAtlas (philatlas.com, Aug 2026). Used to jump straight to a
  /// barangay on search/suggestion without a network round-trip, and by
  /// the map picker to sanity-check reverse-geocoded labels.
  static const Map<String, LatLngDeg> barangayCoordinates = {
    'Agbago': LatLngDeg(11.8088, 122.1464),
    'Agdugayan': LatLngDeg(11.7693, 122.1594),
    'Antipolo': LatLngDeg(11.8021, 122.1226),
    'Aparicio': LatLngDeg(11.6950, 122.1879),
    'Aquino': LatLngDeg(11.8185, 122.1104),
    'Aslum': LatLngDeg(11.8239, 122.1560),
    'Bagacay': LatLngDeg(11.7919, 122.1659),
    'Batuan': LatLngDeg(11.7917, 122.1506),
    'Buenavista': LatLngDeg(11.8014, 122.1803),
    'Bugtongbato': LatLngDeg(11.8061, 122.2094),
    'Cabugao': LatLngDeg(11.7432, 122.1919),
    'Capilijan': LatLngDeg(11.7889, 122.1571),
    'Colongcolong': LatLngDeg(11.8188, 122.1732),
    'Laguinbanua': LatLngDeg(11.8082, 122.1580),
    'Mabusao': LatLngDeg(11.7726, 122.1286),
    'Malindog': LatLngDeg(11.7015, 122.1808),
    'Maloco': LatLngDeg(11.7842, 122.1526),
    'Mina-a': LatLngDeg(11.6669, 122.1927),
    'Monlaque': LatLngDeg(11.7104, 122.1832),
    'Naile': LatLngDeg(11.7666, 122.1765),
    'Naisud': LatLngDeg(11.8055, 122.1941),
    'Naligusan': LatLngDeg(11.7752, 122.1733),
    'Ondoy': LatLngDeg(11.8193, 122.1227),
    'Poblacion': LatLngDeg(11.8188, 122.1607),
    'Polo': LatLngDeg(11.8177, 122.1652),
    'Regador': LatLngDeg(11.7801, 122.2020),
    'Rivera': LatLngDeg(11.7313, 122.2016),
    'Rizal': LatLngDeg(11.7813, 122.1724),
    'San Isidro': LatLngDeg(11.8119, 122.1796),
    'San Jose': LatLngDeg(11.7406, 122.1770),
    'Santa Cruz': LatLngDeg(11.7931, 122.1411),
    'Tagbaya': LatLngDeg(11.8161, 122.1298),
    'Tul-ang': LatLngDeg(11.8085, 122.1675),
    'Unat': LatLngDeg(11.7808, 122.1647),
  };

  static LatLngDeg? coordinatesForBarangay(String barangay) =>
      barangayCoordinates[barangay];

  /// Nearest known barangay center to [lat]/[lng] and its distance (km).
  static MapEntry<String, double> nearestBarangay(double lat, double lng) {
    String bestName = '';
    var bestKm = double.infinity;
    for (final entry in barangayCoordinates.entries) {
      final d = haversineKm(lat, lng, entry.value.lat, entry.value.lng);
      if (d < bestKm) {
        bestKm = d;
        bestName = entry.key;
      }
    }
    return MapEntry(bestName, bestKm);
  }

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

/// Simple lat/lng pair usable in const collections.
class LatLngDeg {
  final double lat;
  final double lng;
  const LatLngDeg(this.lat, this.lng);
}
