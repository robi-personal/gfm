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
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260, maxHeight: 260),
            child: SvgPicture.asset(
              'assets/login_banner.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 36),
        const Text(
          'Turn anything into\na form or quiz.',
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(
            'Generate forms and quizzes with AI from a YouTube video, PDF, web page, or a photo of printed pages — right from your phone.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
