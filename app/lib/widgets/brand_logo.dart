import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo "ProServiço" — Pro em azul, Serviço em vermelho (padrão web).
class BrandLogo extends StatelessWidget {
  final double fontSize;
  final bool compact;

  const BrandLogo({super.key, this.fontSize = 22, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Pro',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: compact ? 'S' : 'Serviço',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
