import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../../core/services/alert_service.dart';
import '../../services/map_layer_service.dart';
import '../widgets/top_indicator_bar.dart';
import '../widgets/bottom_timeline_dock.dart';
import '../widgets/inspection_bottom_sheet.dart';

class EcoGISScreen extends StatefulWidget {
  const EcoGISScreen({super.key});
  @override
  State<EcoGISScreen> createState() => _EcoGISScreenState();
}

class _EcoGISScreenState extends State<EcoGISScreen> {
  MapLibreMapController? _mapController;
  String _selectedIndicator = 'LST';
  int _currentMonthIndex = 86;
  bool _isPlaying = false;
  Timer? _animationTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String? _selectedWardName;
  String? _selectedDistrict;
  double? _selectedVal;
  List<double> _selectedTimeseries = const [];

  bool _showFill = true;
  bool _showLine = true;
  bool _showBackground = true;
  bool _showLabels = true;

  int _droughtCount = 0;
  List<String> _droughtTop = const [];
  bool _bannerDismissed = false;
  int _lastDroughtCount = 0;

  void _onMapCreated(MapLibreMapController controller) => _mapController = controller;

  void _onStyleLoaded() async {
    if (_mapController != null) {
      await MapLayerService.init(_mapController!);
      await MapLayerService.updateChoropleth(_mapController!, _selectedIndicator, _currentMonthIndex, updateStyle: true);
      await _refreshDroughtAlert();
    }
  }

  void _onSelectIndicator(String id) async {
    setState(() => _selectedIndicator = id);
    if (_mapController != null) {
      await MapLayerService.updateChoropleth(_mapController!, id, _currentMonthIndex, updateStyle: true);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _refreshDroughtAlert() async {
    final hot = MapLayerService.scanDrought(_currentMonthIndex);
    if (!mounted) return;
    setState(() {
      if (_lastDroughtCount == 0 && hot.length > 0) _bannerDismissed = false;
      _lastDroughtCount = hot.length;
      _droughtCount = hot.length;
      _droughtTop = hot.take(5).map((e) => e['name'].toString()).toList();
    });
    if (hot.isNotEmpty) {
      await AlertService.notifyDrought(_currentMonthIndex, hot.length, _droughtTop);
    }
  }

  // TC10 – GPS thật (geolocator)
  Future<void> _locateMe() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('📴 Thiết bị chưa bật định vị'); return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _toast('🔒 Chưa được cấp quyền vị trí'); return;
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      final me = LatLng(pos.latitude, pos.longitude);
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(me, 13));
      final feature = await MapLayerService.queryWard(null, const Point(0, 0), me, _selectedIndicator, _currentMonthIndex);
      if (feature == null) { _toast('📍 Ngoài vùng 168 đơn vị hành chính'); return; }
      setState(() {
        _selectedWardName = feature['name']?.toString();
        _selectedDistrict = feature['district']?.toString();
        _selectedVal = (feature['val'] as num?)?.toDouble() ?? 0.0;
        _selectedTimeseries = (feature['timeseries'] as List?)?.cast<double>() ?? const [];
      });
      _showBottomSheet();
    } catch (e) { _toast('📍 Lỗi định vị: $e'); }
  }

  Future<LatLng> _resolveLatLng(Point<double> point, LatLng fallback) async {
    final c = _mapController;
    if (c == null) return fallback;
    final size = MediaQuery.of(context).size;
    try { return await c.toLatLng(point); } catch (_) {}
    try {
      final region = await c.getVisibleRegion();
      final ne = region.northeast, sw = region.southwest;
      return LatLng(
        ne.latitude - (point.y / size.height) * (ne.latitude - sw.latitude),
        sw.longitude + (point.x / size.width) * (ne.longitude - sw.longitude),
      );
    } catch (_) { return fallback; }
  }

  void _onMapClick(Point<double> point, LatLng coords) async {
    final safe = await _resolveLatLng(point, coords);
    final feature = await MapLayerService.queryWard(_mapController, point, safe, _selectedIndicator, _currentMonthIndex);
    if (feature == null) { _toast('🕳 Tọa độ ngoài vùng'); return; }
    setState(() {
      _selectedWardName = feature['name']?.toString();
      _selectedDistrict = feature['district']?.toString();
      _selectedVal = (feature['val'] as num?)?.toDouble() ?? 0.0;
      _selectedTimeseries = (feature['timeseries'] as List?)?.cast<double>() ?? const [];
    });
    _showBottomSheet();
  }

  void _pickCenter() async {
    final c = _mapController;
    if (c == null) return;
    try {
      final region = await c.getVisibleRegion();
      final lat = (region.northeast.latitude + region.southwest.latitude) / 2;
      final lng = (region.northeast.longitude + region.southwest.longitude) / 2;
      final feature = await MapLayerService.queryWard(null, const Point(0, 0), LatLng(lat, lng), _selectedIndicator, _currentMonthIndex);
      if (feature == null) { _toast('🕳 Tâm màn hình ngoài vùng'); return; }
      setState(() {
        _selectedWardName = feature['name']?.toString();
        _selectedDistrict = feature['district']?.toString();
        _selectedVal = (feature['val'] as num?)?.toDouble() ?? 0.0;
        _selectedTimeseries = (feature['timeseries'] as List?)?.cast<double>() ?? const [];
      });
      _showBottomSheet();
    } catch (e) { _toast('Lỗi: $e'); }
  }

  Future<void> _toggleLayer(String key, bool visible) async {
    setState(() {
      if (key == 'wards-fill') { _showFill = visible; }
      else if (key == 'wards-line') { _showLine = visible; }
      else if (key == 'background') { _showBackground = visible; }
      else { _showLabels = visible; }
    });
    final c = _mapController;
    if (c == null) return;
    final List<String> candidates = key == 'background'
        ? const ['Satellite', 'satellite', 'background']
        : key == 'labels' ? const ['Labels', 'labels', 'place_labels'] : [key];
    for (final id in candidates) {
      try { await c.setLayerVisibility(id, visible); return; } catch (_) {}
    }
  }

  void _toggleAnimation() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _animationTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) async {
        setState(() { _currentMonthIndex = (_currentMonthIndex < 119) ? _currentMonthIndex + 1 : 0; });
        if (_mapController != null) {
          await MapLayerService.updateChoropleth(_mapController!, _selectedIndicator, _currentMonthIndex, updateStyle: false);
        }
        await _refreshDroughtAlert();
      });
    } else { _animationTimer?.cancel(); }
  }

  void _showBottomSheet() {
    if (_selectedWardName == null) return;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => InspectionBottomSheet(
        wardName: _selectedWardName!,
        district: _selectedDistrict!,
        month: (_currentMonthIndex % 12) + 1,
        year: 2017 + (_currentMonthIndex ~/ 12),
        currentVal: _selectedVal ?? 0.0,
        selectedIndicator: _selectedIndicator,
        timeseries: _selectedTimeseries,
      ),
    );
  }

  @override
  void dispose() { _animationTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildLayerDrawer(),
      body: Stack(
        children: [
          MapLibreMap(
            initialCameraPosition: const CameraPosition(target: LatLng(10.7769, 106.7009), zoom: 9.2),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: _onMapClick,
            styleString: "https://api.maptiler.com/maps/hybrid/style.json?key=get_your_own_OpIi9ZULNHzrESv6T2vL",
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, left: 16,
            child: FloatingActionButton.small(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              foregroundColor: Colors.white,
              tooltip: 'Bật/tắt layer (TC09)',
              child: const Icon(Icons.menu, size: 20),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16, left: 80, right: 16,
            child: TopIndicatorBar(selectedIndicator: _selectedIndicator, onSelectIndicator: _onSelectIndicator),
          ),
          if (_droughtCount > 0 && !_bannerDismissed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 150,
              right: 16,
              child: GestureDetector(
                onTap: () => _toast('⚠️ TVDI ≥ 0.7: ${_droughtTop.join(', ')}'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFFF3B30).withValues(alpha: 0.85)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const _PulseDot(),
                    const SizedBox(width: 8),
                    Text('$_droughtCount khu vực hạn nặng',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => setState(() => _bannerDismissed = true),
                      child: const Icon(Icons.close, color: Colors.white54, size: 16),
                    ),
                  ]),
                ),
              ),
            ),
          Positioned(
            right: 20, bottom: 250,
            child: FloatingActionButton.small(
              onPressed: _locateMe,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              tooltip: 'Vị trí hiện tại (TC10 - GPS thật)',
              child: const Icon(Icons.gps_fixed, size: 20),
            ),
          ),
          Positioned(
            right: 20, bottom: 190,
            child: FloatingActionButton.small(
              onPressed: _pickCenter,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              tooltip: 'Xem phường tại TÂM màn hình',
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 16,
            child: BottomTimelineDock(
              currentMonthIndex: _currentMonthIndex, isPlaying: _isPlaying,
              onToggleAnimation: _toggleAnimation,
              onSliderChanged: (val) async {
                setState(() => _currentMonthIndex = val.toInt());
                if (_mapController != null) {
                  await MapLayerService.updateChoropleth(_mapController!, _selectedIndicator, _currentMonthIndex, updateStyle: false);
                }
                await _refreshDroughtAlert();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Điều khiển lớp bản đồ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('MobileGIS – Đề tài 7', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Divider(color: Colors.white24),
            SwitchListTile(title: const Text('Lớp chỉ số LST/NDVI/TVDI', style: TextStyle(color: Colors.white, fontSize: 13)), value: _showFill, onChanged: (v) => _toggleLayer('wards-fill', v)),
            SwitchListTile(title: const Text('Ranh giới hành chính', style: TextStyle(color: Colors.white, fontSize: 13)), value: _showLine, onChanged: (v) => _toggleLayer('wards-line', v)),
            SwitchListTile(title: const Text('Nền vệ tinh', style: TextStyle(color: Colors.white, fontSize: 13)), value: _showBackground, onChanged: (v) => _toggleLayer('background', v)),
            SwitchListTile(title: const Text('Nhãn địa danh', style: TextStyle(color: Colors.white, fontSize: 13)), value: _showLabels, onChanged: (v) => _toggleLayer('labels', v)),
          ],
        ),
      ),
    );
  }
}


class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 10, height: 10,
        decoration: const BoxDecoration(color: Color(0xFFFF3B30), shape: BoxShape.circle),
      ),
    );
  }
}
