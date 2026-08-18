import 'package:flutter/material.dart';

import '../../core/theme/theme_ext.dart';

/// Animated gradient "shimmer" placeholder shown while an image is loading
/// (2026-08-19, explicit user instruction — replaces every spinner/blank
/// loading state on an image, app-wide). [shape]/[borderRadius] mirror
/// whatever the image itself will be clipped to once loaded (circle for
/// avatars, rounded rect for banners/cards) so the placeholder reads as
/// "this image is loading", not a generic unrelated box. Byte-for-byte port
/// of `cliniqnovva/lib/shared/widgets/shimmer_box.dart` (the web dashboard's
/// own copy) — kept as a plain duplicate rather than a shared package since
/// the two apps don't share a common Dart package today.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.shape = BoxShape.rectangle,
    this.borderRadius,
  });

  final BoxShape shape;
  final BorderRadius? borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.appSecondaryBg;
    final highlight = context.isDark
        ? Colors.white.withValues(alpha: 0.18)
        : const Color(0xFFFBFBFC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final sweep = -1.0 + 2.0 * _controller.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.circle
                ? null
                : widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(sweep - 1, 0),
              end: Alignment(sweep + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
