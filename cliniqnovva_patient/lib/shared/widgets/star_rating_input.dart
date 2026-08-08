import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// A tappable 1-5 star picker — the write counterpart to the read-only
/// [RatingStars] (Part 20). Same `AppColors.skyBlue` filled-star color for
/// consistency with every other star rendering in the app (Leave Review,
/// Part 24, is the first place a rating is entered rather than displayed).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged, this.size = 32});

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AppIcon(
                AppIcons.star,
                size: size,
                color: i <= value ? AppColors.skyBlue : context.appBorder,
              ),
            ),
          ),
      ],
    );
  }
}
