import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/app_controller.dart';
import 'services/book_repository.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await BookRepository.create();
  final controller = AppController(repository, LocalTtsService());
  await controller.init();
  runApp(AuralisApp(controller: controller));
}
