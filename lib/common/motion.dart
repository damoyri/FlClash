import 'package:flutter/widgets.dart';

abstract final class Md3Durations {
  static const short1 = Duration(milliseconds: 50);
  static const short2 = Duration(milliseconds: 100);
  static const short3 = Duration(milliseconds: 150);
  static const short4 = Duration(milliseconds: 200);

  static const medium1 = Duration(milliseconds: 250);
  static const medium2 = Duration(milliseconds: 300);
  static const medium3 = Duration(milliseconds: 350);
  static const medium4 = Duration(milliseconds: 400);

  static const long1 = Duration(milliseconds: 500);
  static const long2 = Duration(milliseconds: 550);
  static const long3 = Duration(milliseconds: 600);
  static const long4 = Duration(milliseconds: 700);
}

abstract final class Md3Curves {
  static const emphasized = Curves.easeInOutCubicEmphasized;
  static const emphasizedDecelerate = Curves.easeOutCubic;
  static const emphasizedAccelerate = Curves.easeInCubic;
  static const standard = Curves.easeInOutCubic;
  static const standardDecelerate = Curves.easeOut;
  static const standardAccelerate = Curves.easeIn;
}

bool isMotionDisabled(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

Duration motionDuration(BuildContext context, Duration duration) =>
    isMotionDisabled(context) ? Duration.zero : duration;

Curve motionCurve(BuildContext context, Curve curve) =>
    isMotionDisabled(context) ? Curves.linear : curve;
abstract final class Motion {
  static const medium2 = Md3Durations.medium2;
  static const medium4 = Md3Durations.medium4;
  static const emphasizedDecelerate = Md3Curves.emphasizedDecelerate;
  static const emphasizedAccelerate = Md3Curves.emphasizedAccelerate;
}
