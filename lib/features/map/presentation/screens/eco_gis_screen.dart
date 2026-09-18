import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
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

  // TC09 – Layer control theo PDF
  bool _showFill = true;
  bool _showLine = true;
  bool _showBackground = true;
  bool _showLabels = true;

  void _onMapCreated(MapLibreMapController controller) => _mapController = controller;

  void _onStyleLoaded() async {
    if (_mapController != null) {
      await MapLayerService.init(_mapController!);
      await MapLayerService.updateChoropleth(_mapController!, _selectedIndicator, _currentMonthIndex);
    }
  }

  void _onSelectIndicator(String id) async {
    setState(() => _selectedIndicator = id);
    if (_mapController != null) {
      await MapLayerService.updateChoropleth(_mapController!, id, _currentMonthIndex);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Future<LatLng> _resolveLatLng(Point<double> point, LatLng fallback) async {
    final c = _mapController;
    if (c == null) return fallback;
    try {
      return await c.toLatLng(point);
    } catch (_) {}
    try {
      final region = await c.getVisibleRegion();
      final size = MediaQuery.of(context).size;
      final ne = region.northeast, sw = region.southwest;
      return LatLng(
        ne.latitude - (point.y / size.height) * (ne.latitude - sw.latitude),
        sw.longitude + (point.x / size.width) * (ne.longitude - sw.longitude),
      );
    } catch (_) {
      return fallback;
    }
  }

  void _onMapClick(Point<double> point, LatLng coords) async {
    final safe = await _resolveLatLng(point, coords);
    final feature = await MapLayerService.queryWard(
      _mapController, point, safe, _selectedIndicator, _currentMonthIndex,
    );
    if (feature == null) {
      _toast('🕳 Tọa độ ngoài vùng 168 đơn vị hành chính');
      return;
    }
    setState(() {
      _selectedWardName = feature['name']?.toString();
      _selectedDistrict = feature['district']?.toString();
      _selectedVal = (feature['val'] as num?)?.toDouble() ?? 0.0;
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
      final feature = await MapLayerService.queryWard(
        null, const Point(0, 0), LatLng(lat, lng), _selectedIndicator, _currentMonthIndex,
      );
      if (feature == null) {
        _toast('🕳 Tâm màn hình đang ngoài vùng nghiên cứu');
        return;
      }
      setState(() {
        _selectedWardName = feature['name']?.toString();
        _selectedDistrict = feature['district']?.toString();
        _selectedVal = (feature['val'] as num?)?.toDouble() ?? 0.0;
      });
      _showBottomSheet();
    } catch (e) {
      _toast('Lỗi: $e');
    }
  }

  // TC09 – bật/tắt layer bằng API chuẩn của plugin
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
        : key == 'labels'
            ? const ['Labels', 'labels', 'place_labels']
            : [key];
    for (final id in candidates) {
      try {
        await c.setLayerVisibility(id, visible);
        debugPrint('👁 setLayerVisibility($id, $visible) OK');
        return;
      } catch (_) {}
    }
    debugPrint('⚠️ Không tìm thấy layer để bật/tắt: $key');
  }

  void _toggleAnimation() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _animationTimer = Timer.periodic(const Duration(milliseconds: 900), (timer) async {
        setState(() {
          _currentMonthIndex = (_currentMonthIndex < 119) ? _currentMonthIndex + 1 : 0;
        });
        if (_mapController != null) {
          await MapLayerService.updateChoropleth(_mapController!, _selectedIndicator, _currentMonthIndex);
        }
      });
    } else {
      _animationTimer?.cancel();
    }
  }

  void _showBottomSheet() {
    if (_selectedWardName == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => InspectionBottomSheet(
        wardName: _selectedWardName!,
        district: _selectedDistrict!,
        month: (_currentMonthIndex % 12) + 1,
        year: 2017 + (_currentMonthIndex ~/ 12),
        currentVal: _selectedVal ?? 0.0,
        selectedIndicator: _selectedIndicator,
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
            child: TopIndicatorBar(
              selectedIndicator: _selectedIndicator,
              onSelectIndicator: _onSelectIndicator,
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
              currentMonthIndex: _currentMonthIndex,
              isPlaying: _isPlaying,
              onToggleAnimation: _toggleAnimation,
              onSliderChanged: (val) async {
                setState(() => _currentMonthIndex = val.toInt());
                if (_mapController != null) {
                  await MapLayerService.updateChoropleth(_mapController!, _selectedIndicator, _currentMonthIndex);
                }
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
            const Text('Điều khiển lớp bản đồ',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('MobileGIS – Đề tài 7 (Layer control)',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Divider(color: Colors.white24),
            SwitchListTile(
              title: const Text('Lớp chỉ số LST/NDVI/TVDI', style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showFill,
              onChanged: (v) => _toggleLayer('wards-fill', v),
            ),
            SwitchListTile(
              title: const Text('Ranh giới hành chính', style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showLine,
              onChanged: (v) => _toggleLayer('wards-line', v),
            ),
            SwitchListTile(
              title: const Text('Nền vệ tinh', style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showBackground,
              onChanged: (v) => _toggleLayer('background', v),
            ),
            SwitchListTile(
              title: const Text('Nhãn địa danh', style: TextStyle(color: Colors.white, fontSize: 13)),
              value: _showLabels,
              onChanged: (v) => _toggleLayer('labels', v),
            ),
            const Divider(color: Colors.white24),
            const Text('Ghi chú demo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              '• 2 switch đầu tắt/mở lớp GeoJSON của nhóm.\n'
              '• 2 switch nền/nhãn thuộc style MapTiler; sẽ quản lý tập trung khi nối XYZ tiles từ GeoServer theo kiến trúc PDF.',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
