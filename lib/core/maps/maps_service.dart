import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:bakaloo_flutter_app/core/maps/geo_point.dart';
import 'package:bakaloo_flutter_app/core/maps/route_model.dart';
import 'package:bakaloo_flutter_app/core/utils/haversine.dart';

class MapsService {
  MapsService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 12),
                receiveTimeout: const Duration(seconds: 12),
                headers: const <String, String>{
                  HttpHeaders.userAgentHeader: _userAgent,
                  HttpHeaders.acceptHeader: 'application/json',
                },
              ),
            );

  static const String _userAgent = 'BakalooCustomerDemoMap/1.0';
  static const double _fallbackMetersPerSecond = 6.5;

  final Dio _dio;

  Future<RouteModel?> getRoute(GeoPoint origin, GeoPoint destination) async {
    if (!origin.isValid || !destination.isValid) {
      return null;
    }

    try {
      final response = await _dio.get<dynamic>(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.lng},${origin.lat};${destination.lng},${destination.lat}',
        queryParameters: const <String, dynamic>{
          'alternatives': 'false',
          'overview': 'full',
          'steps': 'false',
          'geometries': 'geojson',
        },
      );

      final data = _asMap(response.data);
      if ('${data['code'] ?? ''}'.toUpperCase() != 'OK') {
        return _straightLineFallback(origin, destination);
      }

      final routes = _asList(data['routes']);
      if (routes.isEmpty) {
        return _straightLineFallback(origin, destination);
      }

      final route = _asMap(routes.first);
      final geometry = _asMap(route['geometry']);
      final coordinates = _asList(geometry['coordinates']);
      final points = coordinates
          .map(_coordinateToPoint)
          .whereType<GeoPoint>()
          .toList(growable: false);

      if (points.isEmpty) {
        return _straightLineFallback(origin, destination);
      }

      return RouteModel(
        points: points,
        distanceMeters: _toDouble(route['distance'])?.round() ??
            _fallbackDistance(origin, destination),
        durationSeconds: _toDouble(route['duration'])?.round() ??
            _fallbackDuration(_fallbackDistance(origin, destination)),
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Customer MapsService.getRoute exception: $error');
        debugPrint('$stackTrace');
      }
      return _straightLineFallback(origin, destination);
    }
  }

  Future<GeoPoint?> geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final response = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: <String, dynamic>{
          'q': trimmed,
          'format': 'jsonv2',
          'limit': 1,
          'addressdetails': 0,
        },
        options: Options(
          headers: const <String, String>{
            HttpHeaders.userAgentHeader: _userAgent,
            'Accept-Language': 'en-IN,en;q=0.9',
          },
        ),
      );

      final results = _asList(response.data);
      if (results.isEmpty) {
        return null;
      }

      final first = _asMap(results.first);
      final lat = _toDouble(first['lat']);
      final lng = _toDouble(first['lon']);
      if (lat == null || lng == null) {
        return null;
      }

      return GeoPoint(lat: lat, lng: lng);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Customer MapsService.geocodeAddress exception: $error');
        debugPrint('$stackTrace');
      }
      return null;
    }
  }

  Future<ReverseGeocodeResult?> reverseGeocode(GeoPoint point) async {
    if (!point.isValid) {
      return null;
    }

    try {
      final response = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: <String, dynamic>{
          'lat': point.lat,
          'lon': point.lng,
          'format': 'jsonv2',
          'addressdetails': 1,
        },
        options: Options(
          headers: const <String, String>{
            HttpHeaders.userAgentHeader: _userAgent,
            'Accept-Language': 'en-IN,en;q=0.9',
          },
        ),
      );

      final data = _asMap(response.data);
      final address = _asMap(data['address']);
      if (data.isEmpty) {
        return null;
      }

      final houseNumber = _readString(address, <String>['house_number']);
      final road =
          _readString(address, <String>['road', 'pedestrian', 'footway']);
      final suburb = _readString(
        address,
        <String>['suburb', 'neighbourhood', 'quarter', 'hamlet'],
      );
      final city = _readString(
        address,
        <String>['city', 'town', 'village', 'municipality', 'county'],
      );
      final state = _readString(address, <String>['state']);
      final pincode = _readString(address, <String>['postcode']);

      final addressLine1 = <String>[houseNumber, road]
          .where((value) => value.trim().isNotEmpty)
          .join(', ')
          .trim();

      return ReverseGeocodeResult(
        displayName: _readString(data, <String>['display_name']),
        addressLine1: addressLine1.isEmpty ? null : addressLine1,
        addressLine2: suburb.isEmpty ? null : suburb,
        city: city.isEmpty ? null : city,
        state: state.isEmpty ? null : state,
        pincode: pincode.isEmpty ? null : pincode,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Customer MapsService.reverseGeocode exception: $error');
        debugPrint('$stackTrace');
      }
      return null;
    }
  }

  RouteModel _straightLineFallback(GeoPoint origin, GeoPoint destination) {
    final distanceMeters = _fallbackDistance(origin, destination);
    return RouteModel(
      points: <GeoPoint>[origin, destination],
      distanceMeters: distanceMeters,
      durationSeconds: _fallbackDuration(distanceMeters),
    );
  }

  int _fallbackDistance(GeoPoint origin, GeoPoint destination) {
    return Haversine.distanceInMeters(
      startLatitude: origin.lat,
      startLongitude: origin.lng,
      endLatitude: destination.lat,
      endLongitude: destination.lng,
    ).round();
  }

  int _fallbackDuration(int distanceMeters) {
    final safeDistance = distanceMeters <= 0 ? 1 : distanceMeters.toDouble();
    return (safeDistance / _fallbackMetersPerSecond).ceil();
  }

  GeoPoint? _coordinateToPoint(dynamic raw) {
    if (raw is! List || raw.length < 2) {
      return null;
    }

    final lng = _toDouble(raw[0]);
    final lat = _toDouble(raw[1]);
    if (lat == null || lng == null) {
      return null;
    }
    return GeoPoint(lat: lat, lng: lng);
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List<dynamic>) {
      return value;
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    return const <dynamic>[];
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}

class ReverseGeocodeResult {
  const ReverseGeocodeResult({
    this.displayName,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
  });

  final String? displayName;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
}
