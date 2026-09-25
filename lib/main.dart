import 'package:flutter/material.dart';
import 'core/services/alert_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants/app_colors.dart';
import 'features/map/presentation/screens/eco_gis_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlertService.init();
  runApp(const EcoGISApp());
}

class EcoGISApp extends StatelessWidget {
  const EcoGISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoGIS TP.HCM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: AppColors.primaryBlue,
        scaffoldBackgroundColor: const Color(0xFF0A0A0C),
        textTheme: GoogleFonts.beVietnamProTextTheme(ThemeData.dark().textTheme),
      ),
      home: const EcoGISScreen(),
    );
  }
}
