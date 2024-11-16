import 'package:workmanager/workmanager.dart';
import 'CustomNotifications.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Check for updates here
    await checkForUpdates();
    return Future.value(true);
  });
}

Future<void> checkForUpdates() async {
  startListeningCustomNotifications();
}
