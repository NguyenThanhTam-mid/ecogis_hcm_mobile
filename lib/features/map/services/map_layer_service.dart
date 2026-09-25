import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';

class MapLayerService {
  static Map<String, dynamic>? _baseGeoJson;

  static Future<void> init(MapLibreMapController controller) async {
    if (_baseGeoJson == null) {
      final jsonStr = await rootBundle.loadString('assets/geojson/tphcm_micro_wards_168.geojson');
      _baseGeoJson = jsonDecode(jsonStr);
    }
    await controller.addSource("wards-source", GeojsonSourceProperties(data: _baseGeoJson));
    await controller.addFillLayer("wards-source", "wards-fill", FillLayerProperties(fillColor: '#F46D43', fillOpacity: 0.6));
    await controller.addLineLayer("wards-source", "wards-line", const LineLayerProperties(lineColor: "#FFFFFF", lineWidth: 1.0, lineOpacity: 0.5));
    debugPrint("✅ MapLayerService: Đã khởi tạo 168 phường/xã!");
  }

  static String wardNameOf(Map<String, dynamic> props) {
    final n = (props['ten_xa'] ?? props['Ten_PX'] ?? props['name'] ?? '').toString();
    return n.isEmpty ? 'Khu vực chưa rõ tên' : n;
  }

  static String districtOf(Map<String, dynamic> props) {
    final s = (props['sap_nhap'] ?? '').toString();
    final m = RegExp(r'\(([^)]*(?:Quận|Huyện|Thị|Thành)[^)]*)\)').firstMatch(s);
    if (m != null) return m.group(1)!;
    return (props['ten_tinh'] ?? 'TP.HCM').toString();
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> raw) => {
    'name': wardNameOf(raw),
    'district': districtOf(raw),
    'val': (raw['val'] ?? 0.0),
  };

  static double computeVal(String indicator, int monthIndex, Map<String, dynamic> props, int i) {
    final density = ((props['matdo_km2'] ?? 0) as num).toDouble();
    final dNorm = (density / 60000.0).clamp(0.0, 1.0).toDouble();
    final jitter = ((i * 7) % 5) * 0.02;
    final season = monthIndex % 12;
    if (indicator == 'LST') {
      final hotSeason = (season >= 2 && season <= 4) ? 3.0 : 0.0;
      return 27.5 + hotSeason + dNorm * 8.0 + jitter * 10;
    } else if (indicator == 'NDVI') {
      final rainy = (season >= 5 && season <= 10) ? 0.08 : 0.0;
      return (0.75 - dNorm * 0.45 + rainy + jitter).clamp(0.05, 0.95).toDouble();
    }
    final drySeason = (season <= 3 || season == 11) ? 0.15 : 0.0;
    return (0.25 + drySeason + dNorm * 0.35 + jitter).clamp(0.0, 0.98).toDouble();
  }

  static List<double> getWardTimeseries(String indicator, Map<String, dynamic> props, int i) {
    return List.generate(120, (m) => computeVal(indicator, m, props, i));
  }

  // TC12 – quét toàn bộ 168 đơn vị, trả về danh sách TVDI >= ngưỡng
  static List<Map<String, dynamic>> scanDrought(int monthIndex, {double threshold = 0.7}) {
    final out = <Map<String, dynamic>>[];
    if (_baseGeoJson == null) return out;
    final feats = (_baseGeoJson!['features'] as List<dynamic>);
    for (int i = 0; i < feats.length; i++) {
      final props = (feats[i] as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
      final tvdi = computeVal('TVDI', monthIndex, props, i);
      if (tvdi >= threshold) out.add({'name': wardNameOf(props), 'tvdi': tvdi});
    }
    out.sort((a, b) => (b['tvdi'] as double).compareTo(a['tvdi'] as double));
    return out;
  }

  // Tối ưu: chỉ rebuild layer khi đổi chỉ số (updateStyle=true)
  static Future<void> updateChoropleth(
    MapLibreMapController controller, String indicator, int monthIndex,
    {bool updateStyle = false}
  ) async {
    if (_baseGeoJson == null) return;
    final Map<String, dynamic> newData = jsonDecode(jsonEncode(_baseGeoJson));
    final List<dynamic> feats = newData['features'] as List<dynamic>;
    for (int i = 0; i < feats.length; i++) {
      final props = (feats[i] as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
      props['val'] = computeVal(indicator, monthIndex, props, i);
    }
    await controller.setGeoJsonSource("wards-source", newData);

    if (updateStyle) {
      List<dynamic> colorExpr;
      if (indicator == 'LST') { colorExpr = ['interpolate', ['linear'], ['get', 'val'], 25, '#74ADD1', 32, '#FEE090', 38, '#F46D43', 42, '#A50026']; }
      else if (indicator == 'NDVI') { colorExpr = ['interpolate', ['linear'], ['get', 'val'], 0.0, '#D7C29E', 0.3, '#A1D99B', 0.6, '#41AB5D', 0.9, '#005A32']; }
      else { colorExpr = ['interpolate', ['linear'], ['get', 'val'], 0.0, '#2B83BA', 0.3, '#FFFFBF', 0.6, '#FDAE61', 0.8, '#D7191C']; }
      try { await controller.removeLayer("wards-fill"); } catch (_) {}
      await controller.addFillLayer("wards-source", "wards-fill", FillLayerProperties(fillColor: colorExpr, fillOpacity: 0.75));
    }
  }

  static Future<Map<String, dynamic>?> queryWard(
    MapLibreMapController? controller, Point<double> point, LatLng latLng,
    String indicator, int monthIndex,
  ) async {
    if (controller != null) {
      try {
        final features = await controller.queryRenderedFeatures(point, ['wards-fill'], null);
        if (features.isNotEmpty) {
          final raw = (features.first as Map<String, dynamic>)['properties'] as Map<String, dynamic>;
          final i = (_baseGeoJson?['features'] as List?)?.indexWhere((f) => f['properties']['ma_xa'] == raw['ma_xa']) ?? 0;
          final out = _normalize(raw);
          out['val'] = computeVal(indicator, monthIndex, raw, i);
          out['timeseries'] = getWardTimeseries(indicator, raw, i);
          return out;
        }
      } catch (e) { debugPrint("⚠️ queryRenderedFeatures lỗi: $e"); }
    }
    return _queryByGeometry(latLng, indicator, monthIndex);
  }

  static Map<String, dynamic>? _queryByGeometry(LatLng latLng, String indicator, int monthIndex) {
    if (_baseGeoJson == null) return null;
    final feats = (_baseGeoJson!['features'] as List<dynamic>);
    for (int i = 0; i < feats.length; i++) {
      try {
        final fm = feats[i] as Map<String, dynamic>;
        final geom = fm['geometry'];
        if (geom is! Map<String, dynamic>) continue;
        if (_hitGeometry(geom, latLng.latitude, latLng.longitude)) {
          final raw = fm['properties'] as Map<String, dynamic>;
          final out = _normalize(raw);
          out['val'] = computeVal(indicator, monthIndex, raw, i);
          out['timeseries'] = getWardTimeseries(indicator, raw, i);
          return out;
        }
      } catch (e) { debugPrint('⚠️ Bỏ qua feature #$i lỗi: $e'); }
    }
    return null;
  }

  static bool _hitGeometry(Map<String, dynamic> geom, double lat, double lng) {
    final type = geom['type'];
    if (type == 'Polygon') return _hitPolygon(geom['coordinates'] as List<dynamic>, lat, lng);
    if (type == 'MultiPolygon') {
      for (final poly in (geom['coordinates'] as List<dynamic>)) {
        if (_hitPolygon(poly as List<dynamic>, lat, lng)) return true;
      }
    }
    return false;
  }

  static bool _hitPolygon(List<dynamic> rings, double lat, double lng) {
    if (rings.isEmpty) return false;
    return _pointInRing(rings[0] as List<dynamic>, lat, lng);
  }

  static bool _pointInRing(List<dynamic> ring, double lat, double lng) {
    bool inside = false;
    int j = ring.length - 1;
    for (int i = 0; i < ring.length; j = i++) {
      final pi = ring[i] as List<dynamic>; final pj = ring[j] as List<dynamic>;
      final xi = (pi[0] as num).toDouble(), yi = (pi[1] as num).toDouble();
      final xj = (pj[0] as num).toDouble(), yj = (pj[1] as num).toDouble();
      if (((yi > lat) != (yj > lat)) && (lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi)) inside = !inside;
    }
    return inside;
  }
}
