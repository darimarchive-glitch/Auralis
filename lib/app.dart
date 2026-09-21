import 'package:adwaita_gtk/adwaita_gtk.dart';
import 'package:flutter/material.dart';

import 'controllers/app_controller.dart';
import 'ui/library_page.dart';

class AuralisApp extends StatelessWidget {
  const AuralisApp({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        title: 'Auralis Reader',
        debugShowCheckedModeBanner: false,
        theme: AdwaitaThemeData.light(),
        darkTheme: AdwaitaThemeData.dark(),
        themeMode: controller.settings.themeMode,
        home: LibraryPage(controller: controller),
      ),
    );
  }
}
