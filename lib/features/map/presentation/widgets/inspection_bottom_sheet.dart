import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

class InspectionBottomSheet extends StatelessWidget {
  final String wardName, district, selectedIndicator;
  final int month, year;
  final double currentVal;
  final List<double> timeseries; // DỮ LIỆU THẬT 120 THÁNG

  const InspectionBottomSheet({
    super.key, required this.wardName, required this.district,
    required this.month, required this.year, required this.currentVal,
    required this.selectedIndicator, required this.timeseries,
  });

  // LẤY DỮ LIỆU CỦA CÙNG MỘT THÁNG TRONG 10 NĂM ĐỂ SO SÁNH KHOA HỌC
  List<FlSpot> _generateChartData() {
    List<FlSpot> spots = [];
    int targetMonth = month - 1; 
    for (int yr = 0; yr < 10; yr++) {
      int idx = yr * 12 + targetMonth;
      if (idx < timeseries.length) {
        spots.add(FlSpot(yr.toDouble(), timeseries[idx]));
      }
    }
    return spots;
  }

  Color get _accentColor {
    if (selectedIndicator == 'LST') return AppColors.lstColors.last;
    if (selectedIndicator == 'NDVI') return AppColors.ndviColors.last;
    return AppColors.tvdiColors.last;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDroughtHigh = selectedIndicator == 'TVDI' && currentVal >= 0.7;
    final spots = _generateChartData();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wardName, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w800, fontSize: 20, color: Colors.white)),
                    Text(district, style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white54)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text("${month.toString().padLeft(2, '0')}/$year", style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.bold, color: _accentColor)),
                )
              ],
            ),
            const SizedBox(height: 16),
            if (isDroughtHigh)
              Container(
                padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.alertBgRed.withValues(alpha: 0.15), border: Border.all(color: AppColors.alertBorderRed), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.alertRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text("CẢNH BÁO: TVDI ≥ 0.7 - Nguy cơ khô hạn nặng!", style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.alertRed))),
                ]),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Giá trị $selectedIndicator hiện tại:", style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white54)),
                const SizedBox(height: 4),
                Text(
                  selectedIndicator == 'LST' ? "${currentVal.toStringAsFixed(1)}°C" : currentVal.toStringAsFixed(2),
                  style: GoogleFonts.beVietnamPro(fontSize: 32, fontWeight: FontWeight.w800, color: _accentColor),
                ),
              ]),
            ),
            const SizedBox(height: 24),
            Text("Diễn biến chuỗi thời gian 10 năm (2017 – 2026):", style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 22, interval: 3,
                        getTitlesWidget: (val, _) => Text('${2017 + val.toInt()}', style: GoogleFonts.beVietnamPro(fontSize: 10, color: Colors.white30)),
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots, isCurved: true, curveSmoothness: 0.3, color: _accentColor, barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [_accentColor.withValues(alpha: 0.4), _accentColor.withValues(alpha: 0.0)],
                      )),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.black.withValues(alpha: 0.8),
                      getTooltipItems: (touchedSpots) => touchedSpots.map((e) => LineTooltipItem(
                        e.y.toStringAsFixed(2), GoogleFonts.beVietnamPro(color: Colors.white, fontWeight: FontWeight.bold),
                      )).toList(),
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 500),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
