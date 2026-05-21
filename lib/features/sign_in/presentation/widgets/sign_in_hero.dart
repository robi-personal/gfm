import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/design.dart';

class SignInHero extends StatelessWidget {
  const SignInHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/login_banner.svg',
          width: 260,
          height: 260,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 36),
        const Text(
          'Build Google Forms,\npowered by AI.',
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'Generate, import, and manage forms in seconds — without leaving your phone.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
