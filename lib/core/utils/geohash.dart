import 'dart:math' as math;

const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String geohashEncode(double latitude, double longitude, {int precision = 9}) {
  double latMin = -90.0, latMax = 90.0;
  double lngMin = -180.0, lngMax = 180.0;
  final buffer = StringBuffer();
  var isEven = true;
  var bit = 0;
  var ch = 0;

  while (buffer.length < precision) {
    if (isEven) {
      final mid = (lngMin + lngMax) / 2;
      if (longitude >= mid) {
        ch |= (1 << (4 - bit));
        lngMin = mid;
      } else {
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        ch |= (1 << (4 - bit));
        latMin = mid;
      } else {
        latMax = mid;
      }
    }

    isEven = !isEven;
    if (bit < 4) {
      bit++;
    } else {
      buffer.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return buffer.toString();
}

class GeohashBounds {
  final double minLat, maxLat, minLng, maxLng;
  GeohashBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);

  double get latHeight => maxLat - minLat;
  double get lngWidth => maxLng - minLng;
  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;
}

GeohashBounds geohashDecodeBounds(String hash) {
  double latMin = -90.0, latMax = 90.0;
  double lngMin = -180.0, lngMax = 180.0;
  var isEven = true;

  for (final char in hash.split('')) {
    final idx = _base32.indexOf(char);
    for (var i = 4; i >= 0; i--) {
      final bit = (idx >> i) & 1;
      if (isEven) {
        final mid = (lngMin + lngMax) / 2;
        if (bit == 1) {
          lngMin = mid;
        } else {
          lngMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (bit == 1) {
          latMin = mid;
        } else {
          latMax = mid;
        }
      }
      isEven = !isEven;
    }
  }
  return GeohashBounds(latMin, latMax, lngMin, lngMax);
}

List<String> geohashNeighbors(String hash) {
  final bounds = geohashDecodeBounds(hash);
  final precision = hash.length;
  final neighbors = <String>{};

  for (final dLat in [-1, 0, 1]) {
    for (final dLng in [-1, 0, 1]) {
      if (dLat == 0 && dLng == 0) continue;
      var lat = bounds.centerLat + dLat * bounds.latHeight;
      var lng = bounds.centerLng + dLng * bounds.lngWidth;
      lat = lat.clamp(-90.0, 90.0);
      if (lng > 180) lng -= 360;
      if (lng < -180) lng += 360;
      neighbors.add(geohashEncode(lat, lng, precision: precision));
    }
  }
  return neighbors.toList();
}

double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLng = _degToRad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_degToRad(lat1)) * math.cos(_degToRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  final c = 2 * math.asin(math.sqrt(a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

int geohashPrecisionForRadiusKm(double radiusKm) {
  const table = [
    [1, 5000.0],
    [2, 1250.0],
    [3, 156.0],
    [4, 39.1],
    [5, 4.89],
    [6, 1.22],
    [7, 0.153],
    [8, 0.0382],
    [9, 0.00477],
  ];
  for (final entry in table) {
    if (entry[1] >= radiusKm * 2) return entry[0].toInt();
  }
  return 9;
}
