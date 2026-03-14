import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
// import 'package:google_sign_in/google_sign_in.dart';
import 'package:school_management_system/public/auth/auth_methods.dart';
import 'package:school_management_system/public/config/user_information.dart';
import 'package:school_management_system/public/notifications/notification_push_bridge.dart';
import 'package:school_management_system/public/utils/constant.dart';
import 'package:school_management_system/public/utils/font_style.dart';
import 'package:school_management_system/public/widgets/circuled_button.dart';
import 'package:school_management_system/public/widgets/custom_button.dart';
import 'package:school_management_system/public/widgets/custom_formfield.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:school_management_system/student/view/Home/messaging.dart';
import '../utils/util.dart';
import 'login_label.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isPassword = true;
  bool student = false;
  bool teacher = false;
  bool admin = false;
  bool parent = false;
  var stcolor = gradientColor2,
      adcolor = gradientColor2,
      tecolor = gradientColor2,
      parcolor = gradientColor2;
  var sticotextcolor = gray,
      adicotextcolor = gray,
      teicotextcolor = gray,
      paricotextcolor = gray;

  // GoogleSignInAccount? _userObj;
  // GoogleSignIn _googleSignIn = GoogleSignIn();
  GetStorage storage = GetStorage();
  String url = "";
  String name = "";
  String email = "";
  String txt1 = "", txt2 = "";
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  var formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  initialMessage() async {
    var message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      Navigator.of(context).pushNamed("Studenthome");
    }
  }

  @override
  void initState() {
    super.initState();
    student = true;
    stcolor = gradientColor;
    sticotextcolor = Colors.white;
    initialMessage();
    fbm.getToken().then((token) {
      print("=================================================");
      print(token);
      UserInformation.Token = token;
      print("=================================================");
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void setstring() {
    _passwordController.text = txt2;
  }

  Future<void> Login() async {
    if (!formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoading = true;
    });
    try {
      String res = await AuthMethods().loginStudent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (res != "success") {
        showSnackBar(res, context);
        return;
      }

      if (student) {
        QuerySnapshot snap = await FirebaseFirestore.instance
            .collection('students')
            .where("uid", isEqualTo: UserInformation.User_uId)
            .limit(1)
            .get();
        if (snap.docs.isEmpty) {
          showSnackBar("You are not a student", context);
          return;
        }

        final data = snap.docs.first.data();
        UserInformation.fees = (data['fees'] ?? '').toString();
        UserInformation.fullfees =
          (data['full_fees'] ?? data['fees'] ?? '').toString();
        UserInformation.classid = (data['class_id'] ?? '').toString();
        UserInformation.first_name = (data['first_name'] ?? '').toString();
        UserInformation.last_name = (data['last_name'] ?? '').toString();
        UserInformation.phone = (data['phone'] ?? '').toString();
        UserInformation.parentphone = (data['parent_phone'] ?? '').toString();
        UserInformation.classroom = (data['class_name'] ?? '').toString();
        UserInformation.clasname = (data['class_name'] ?? '').toString();
        UserInformation.urlAvatr = (data['urlAvatar'] ?? '').toString();
        UserInformation.grade_average =
            ((data['grade_average'] as num?)?.toDouble()) ??
                (double.tryParse((data['grade_average'] ?? '0').toString()) ??
                    0.0);
        UserInformation.grade =
            (int.tryParse((data['grade'] ?? '0').toString()) ?? 0);

        await FirebaseFirestore.instance
            .collection('students')
            .doc(snap.docs.first.id)
            .update({'token': UserInformation.Token ?? ''});
        await storage.write('role', 'student');
        await storage.write('classid', UserInformation.classid);
        NotificationPushBridge.start(
          uid: UserInformation.User_uId,
          role: 'student',
          classId: UserInformation.classid,
        );
        Get.offAllNamed('/sthome');
        return;
      }

      if (teacher) {
        bool okte = false;
        QuerySnapshot snap = await FirebaseFirestore.instance
            .collection('teacher')
            .where("uid", isEqualTo: UserInformation.User_uId)
            .get();
        if (snap.docs.isNotEmpty) {
          okte = true;
        }
        if (okte) {
          await FirebaseFirestore.instance
              .collection('teacher')
              .where('uid', isEqualTo: UserInformation.User_uId)
              .get()
              .then((value) async {
            for (var i = 0; i < value.docs.length; i++) {
              UserInformation.first_name = value.docs[i]['first_name'];
              UserInformation.last_name = value.docs[i]['last_name'];
              UserInformation.phone = value.docs[i]['phone'];
              UserInformation.Subjects = value.docs[i]['subjects'];
              UserInformation.email = value.docs[i]['email'];
              UserInformation.urlAvatr = value.docs[i]['urlAvatar'];
            }
          });
          await FirebaseFirestore.instance
              .collection('teacher')
              .doc(UserInformation.User_uId)
              .update({'token': UserInformation.Token});
          await storage.write('role', 'teacher');
          NotificationPushBridge.start(
            uid: UserInformation.User_uId,
            role: 'teacher',
          );
          Get.offAllNamed('/teahome');
          return;
        } else {
          showSnackBar("You are not a teacher", context);
          return;
        }
      }

      if (admin) {
        bool okad = false;
        QuerySnapshot snap = await FirebaseFirestore.instance
            .collection('admins')
            .where("uid", isEqualTo: UserInformation.User_uId)
            .get();
        if (snap.docs.isNotEmpty) {
          okad = true;
          for (var doc in snap.docs) {
            UserInformation.first_name = doc['first_name'];
            UserInformation.last_name = doc['last_name'];
            UserInformation.email = doc['email'];
            UserInformation.urlAvatr = doc['urlAvatar'];
            UserInformation.phone = doc['phone'] ?? '';
          }
        }
        if (okad) {
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(UserInformation.User_uId)
              .set({'token': UserInformation.Token ?? ''}, const SetOptions(merge: true));
          await storage.write('role', 'admin');
          NotificationPushBridge.start(
            uid: UserInformation.User_uId,
            role: 'admin',
          );
          Get.offAllNamed('/adminhome');
          return;
        } else {
          showSnackBar("You are not an admin", context);
          return;
        }
      }

      if (parent) {
        bool okpar = false;
        QuerySnapshot snap = await FirebaseFirestore.instance
            .collection('parents')
            .where("uid", isEqualTo: UserInformation.User_uId)
            .get();
        if (snap.docs.isNotEmpty) {
          okpar = true;
          for (var doc in snap.docs) {
            UserInformation.first_name = doc['first_name'];
            UserInformation.last_name = doc['last_name'];
            UserInformation.email = doc['email'];
            UserInformation.phone = doc['phone'] ?? '';
            UserInformation.urlAvatr = doc['urlAvatar'];
          }
        }
        if (okpar) {
          UserInformation.uParent = true;
          await FirebaseFirestore.instance
              .collection('parents')
              .doc(UserInformation.User_uId)
              .set({'token': UserInformation.Token ?? ''}, const SetOptions(merge: true));
          await storage.write('role', 'parent');
          NotificationPushBridge.start(
            uid: UserInformation.User_uId,
            role: 'parent',
          );
          Get.offAllNamed('/parhome');
          return;
        } else {
          // Parent is authenticated but not registered yet — send to registration
          Get.toNamed('/verifyparent');
          return;
        }
      }

      showSnackBar("Please select your role", context);
    } catch (e) {
      showSnackBar(e.toString(), context);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Pics pics = Pics();
    Size size = MediaQuery.of(context).size;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            image: DecorationImage(
                image: AssetImage(
                  "assets/images/login-background-squares.png",
                ),
                fit: BoxFit.cover),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(
                      height: 72.h,
                    ),
                    const Loginlabel(),
                    SizedBox(
                      height: size.height / 10,
                    ),
                    Text(
                      "I am",
                      style: sfBoldStyle(fontSize: 24, color: gray),
                    ),
                    SizedBox(
                      height: 32.h,
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 28.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          circuledButton(
                              pic: pics.teacherGreyPic,
                              text: 'teacher',
                              background: tecolor,
                              icontextcolor: teicotextcolor,
                              press: () {
                                setState(() {
                                  adcolor = gradientColor2;
                                  tecolor = gradientColor;
                                  parcolor = gradientColor2;
                                  stcolor = gradientColor2;
                                  adicotextcolor = gray;
                                  teicotextcolor = Colors.white;
                                  sticotextcolor = gray;
                                  paricotextcolor = gray;
                                  admin = false;
                                  teacher = true;
                                  student = false;
                                  parent = false;
                                });
                              }),
                          circuledButton(
                              pic: pics.studentGreyPic,
                              text: 'student',
                              background: stcolor,
                              icontextcolor: sticotextcolor,
                              press: () {
                                setState(() {
                                  adcolor = gradientColor2;
                                  tecolor = gradientColor2;
                                  parcolor = gradientColor2;
                                  stcolor = gradientColor;
                                  adicotextcolor = gray;
                                  teicotextcolor = gray;
                                  sticotextcolor = Colors.white;
                                  paricotextcolor = gray;
                                  admin = false;
                                  teacher = false;
                                  student = true;
                                  parent = false;
                                });
                              }),
                          circuledButton(
                              pic: pics.parentGreyPic,
                              text: 'parent',
                              background: parcolor,
                              icontextcolor: paricotextcolor,
                              press: () {
                                setState(() {
                                  adcolor = gradientColor2;
                                  tecolor = gradientColor2;
                                  parcolor = gradientColor;
                                  stcolor = gradientColor2;
                                  adicotextcolor = gray;
                                  teicotextcolor = gray;
                                  sticotextcolor = gray;
                                  paricotextcolor = Colors.white;
                                  admin = false;
                                  teacher = false;
                                  student = false;
                                  parent = true;
                                });
                              }),
                          circuledButton(
                              pic: pics.adminGreyPic,
                              text: 'admin',
                              background: adcolor,
                              icontextcolor: adicotextcolor,
                              press: () {
                                setState(() {
                                  adcolor = gradientColor;
                                  tecolor = gradientColor2;
                                  parcolor = gradientColor2;
                                  stcolor = gradientColor2;
                                  adicotextcolor = Colors.white;
                                  teicotextcolor = gray;
                                  sticotextcolor = gray;
                                  paricotextcolor = gray;
                                  admin = true;
                                  teacher = false;
                                  student = false;
                                  parent = false;
                                });
                              }),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 32.h,
                    ),
                    Form(
                        key: formKey,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: Column(children: [
                            customFormField(
                              controller: _emailController,
                              label: 'Email',
                              prefix: Icons.email,
                              onChange: (String val) {},
                              type: TextInputType.emailAddress,
                              validate: (String? value) {
                                if (value!.isEmpty) {
                                  return 'email must not be empty';
                                }
                                return null;
                              },
                            ),
                            SizedBox(
                              height: 24.h,
                            ),
                            customFormField(
                              controller: _passwordController,
                              label: 'Password',
                              prefix: Icons.lock,
                              onChange: (String val) {
                                txt2 = _passwordController.text;
                              },
                              suffix: isPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              isPassword: isPassword,
                              suffixPressed: () {
                                setState(() {
                                  isPassword = !isPassword;
                                  setstring();
                                });
                              },
                              type: TextInputType.visiblePassword,
                              validate: (String? value) {
                                if (value!.isEmpty) {
                                  return 'password must not be empty';
                                }
                                return null;
                              },
                            ),
                            SizedBox(
                              height: 20.h,
                            ),
                          ]),
                        ),
                      ),
                    SizedBox(
                      height: 32.h,
                    ),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : CustomButton(
                            press: Login,
                          ),
                    SizedBox(
                      height: 32.h,
                    ),
                    SizedBox(
                      height: 32.h,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
