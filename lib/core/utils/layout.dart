import 'package:flutter/widgets.dart';

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.shortestSide >= 600;
