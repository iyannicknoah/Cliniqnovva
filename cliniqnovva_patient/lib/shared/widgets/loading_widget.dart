import 'package:flutter/material.dart';

import '../../core/theme/theme_ext.dart';

/// The single loading indicator used everywhere — identical to
/// cliniqnovva/lib/shared/widgets/loading_widget.dart.
class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: context.appPrimary),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(color: context.appSubtext, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
