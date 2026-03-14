




import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:school_management_system/public/notifications/notification_push_bridge.dart';

import '../config/user_information.dart';

class SplashController extends GetxController {
  late GetStorage _storage;
  @override
  void onInit() async {
    _storage = GetStorage();
    await CheckID();
    super.onInit();
  }

  Future<void> CheckID() async {
    String? Uid = await _storage.read('uid');
    String? role = await _storage.read('role');
    if (Uid != null && role != null) {
      UserInformation.User_uId = Uid;
      UserInformation.classid = (_storage.read('classid') ?? '').toString();
      NotificationPushBridge.start(
        uid: Uid,
        role: role,
        classId: UserInformation.classid,
      );
      switch (role) {
        case 'student':
          Get.offAllNamed('/sthome');
          break;
        case 'teacher':
          Get.offAllNamed('/teahome');
          break;
        case 'admin':
          Get.offAllNamed('/adminhome');
          break;
        case 'parent':
          UserInformation.uParent = true;
          Get.offAllNamed('/parhome');
          break;
        default:
          Get.offNamed('/login');
      }
    } else {
      Get.offNamed('/login');
    }
  }
}