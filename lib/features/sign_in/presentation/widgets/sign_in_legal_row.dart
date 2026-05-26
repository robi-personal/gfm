import 'package:flutter/material.dart';

import '../../../../../core/design.dart';
import '../../../../../core/widgets/simple_web_view_page.dart';

class SignInLegalRow extends StatelessWidget {
  const SignInLegalRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegalLink(
          label: 'Privacy Policy',
          url: 'https://gfm.alphaiit.com/privacy.html',
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '·',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.muted2,
            ),
          ),
        ),
        _LegalLink(
          label: 'Terms of Use',
          url: 'https://gfm.alphaiit.com/terms.html',
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  final String label;
  final String url;

  const _LegalLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SimpleWebViewPage(title: label, url: url),
      )),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.purple600,
        ),
      ),
    );
  }
}
