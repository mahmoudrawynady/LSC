import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

extension LoadingExtension on BuildContext {
  Widget loadingWidget({required Color loaderColor}) {
    if (kIsWeb || Platform.isAndroid) {
      return Center(
        child: CircularProgressIndicator(
          color: loaderColor,
        ),
      );
    }
    return Center(child: CupertinoActivityIndicator(color: loaderColor));
  }
}
