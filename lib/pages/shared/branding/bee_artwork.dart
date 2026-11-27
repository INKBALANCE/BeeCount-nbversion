import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BeeIcon extends StatelessWidget {
  final Color color; // 类似 Web 中的 color 属性
  final double size;

  const BeeIcon({super.key, required this.color, this.size = 256});

  @override
  Widget build(BuildContext context) {
    // 图形本身是单色的（水滴填充 currentColor，¥ 为镂空），
    // 亮/暗主题都能直接落在背景上，不需要额外垫底色。
    // 旧版此处会在暗色模式垫一层白色半透明圆，那是为了让蜜蜂的黑色描边
    // 可见；换成水滴后黑色描边不存在了，垫圈只会多出一圈白色光晕，故移除。
    return SvgPicture.asset(
      'assets/bee.svg',
      width: size,
      height: size,
      theme: SvgTheme(
        currentColor: color, // 核心：模拟 CSS 的 currentColor
      ),
    );
  }
}
