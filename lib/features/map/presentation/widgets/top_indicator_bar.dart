import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class TopIndicatorBar extends StatelessWidget {
  final String selectedIndicator;
  final Function(String) onSelectIndicator;

  const TopIndicatorBar({
    super.key,
    required this.selectedIndicator,
    required this.onSelectIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.public, color: AppColors.primaryBlue, size: 20),
                    SizedBox(width: 8),
                    Text("EcoGIS TP.HCM", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("🛰️ LANDSAT 8/9", style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 34,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  _buildTab("LST", "LST (Nhiệt)"),
                  _buildTab("NDVI", "NDVI (Cây)"),
                  _buildTab("TVDI", "TVDI (Khô hạn)"),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildDynamicLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicLegend() {
    String left = "25°C", right = "42°C";
    List<Color> colors = AppColors.lstColors;

    if (selectedIndicator == 'NDVI') {
      left = "0.0 (Trọc)";
      right = "1.0 (Xanh)";
      colors = AppColors.ndviColors;
    } else if (selectedIndicator == 'TVDI') {
      left = "0.0 (Ẩm)";
      right = "1.0 (Hạn)";
      colors = AppColors.tvdiColors;
    }

    return Row(
      children: [
        Text(left, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), gradient: LinearGradient(colors: colors)),
          ),
        ),
        const SizedBox(width: 8),
        Text(right, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }

  Widget _buildTab(String id, String label) {
    final bool isSelected = selectedIndicator == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelectIndicator(id),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? const [BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
          ),
          child: Center(
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? AppColors.primaryBlue : Colors.black54)),
          ),
        ),
      ),
    );
  }
}
