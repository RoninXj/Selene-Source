import 'package:flutter/material.dart';

/// 设备类型工具类
class DeviceUtils {
  // 平板的最小宽度阈值（dp）
  static const double tabletMinWidth = 600.0;

  /// 判断当前设备是否是平板
  ///
  /// 通过屏幕宽度判断，宽度 >= 600dp 视为平板
  static bool isTablet(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    return width >= tabletMinWidth;
  }
}
