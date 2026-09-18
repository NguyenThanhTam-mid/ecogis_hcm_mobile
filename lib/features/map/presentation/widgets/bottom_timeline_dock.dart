import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BottomTimelineDock extends StatelessWidget {
  final int currentMonthIndex;
  final bool isPlaying;
  final VoidCallback onToggleAnimation;
  final Function(double) onSliderChanged;

  const BottomTimelineDock({
    super.key,
    required this.currentMonthIndex,
    required this.isPlaying,
    required this.onToggleAnimation,
    required this.onSliderChanged,
  });

  int get currentYear => 2017 + (currentMonthIndex ~/ 12);
  int get currentMonth => (currentMonthIndex % 12) + 1;
  bool get isAIForecast => currentYear >= 2025;

  @override
  Widget build(BuildContext context) {
    final String monthStr = currentMonth.toString().padLeft(2, '0');

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Tháng $monthStr / $currentYear", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onToggleAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(isPlaying ? "Tạm dừng" : "Animation", style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAIForecast ? const Color(0xFF5856D6).withValues(alpha: 0.15) : const Color(0xFF34C759).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isAIForecast ? "✨ Dự báo AI" : "🛰️ Quan sát thực tế",
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isAIForecast ? const Color(0xFF5856D6) : const Color(0xFF248A3D)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Slider(
              min: 0,
              max: 119,
              divisions: 119,
              value: currentMonthIndex.toDouble(),
              activeColor: AppColors.primaryBlue,
              onChanged: onSliderChanged,
            ),
          ],
        ),
      ),
    );
  }
}
