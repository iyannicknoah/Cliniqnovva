import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_ext.dart';

/// The single avatar component — shows a photo if [photoUrl] is given,
/// otherwise a gradient-initials circle keyed off the first letter of
/// [firstName] (see AppColors.avatarGradients). Always has a 1.5px
/// primary ring.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    required this.firstName,
    this.lastName,
    this.photoUrl,
    this.size = 40,
  });

  final String firstName;
  final String? lastName;
  final String? photoUrl;
  final double size;

  String get _initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = (lastName != null && lastName!.isNotEmpty) ? lastName![0] : '';
    return (first + last).toUpperCase();
  }

  List<Color> get _gradient {
    final letter = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    return AppColors.avatarGradients[letter] ?? AppColors.fallbackGradient;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.appPrimary, width: 1.5),
      ),
      padding: const EdgeInsets.all(1.5),
      child: ClipOval(
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? Image.network(photoUrl!, fit: BoxFit.cover, width: size, height: size)
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}
