import 'dart:io';

import 'package:flutter/material.dart';

import 'theme.dart';

/// The Pack Out banner, shown across every menu: the Shepherd icon, the
/// name "Pack Out by Shepherd", and the byline in small type.
class ShepherdBanner extends StatelessWidget {
  final bool large;
  const ShepherdBanner({super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final iconSize = large ? 54.0 : 40.0;
    final nameSize = large ? 25.0 : 19.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(large ? 14 : 10),
          child: Image.asset(
            'assets/shepherd_icon.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 11),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Pack Out',
                    style: TextStyle(
                      color: kText,
                      fontSize: nameSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' by Shepherd',
                    style: TextStyle(
                      color: kPurpleLight,
                      fontSize: nameSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'BY MSgt Jeremy Davis and Cooper',
              style: TextStyle(
                color: kDim,
                fontSize: large ? 12 : 10.5,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// AppBar carrying the banner — every menu wears the same header.
AppBar shepherdAppBar({List<Widget>? actions}) {
  return AppBar(
    title: const ShepherdBanner(),
    actions: actions,
  );
}

/// An item's portrait wherever the item appears. The photo IS the item's
/// icon; gear with no photo yet falls back to the Shepherd mark.
class ItemPhoto extends StatelessWidget {
  final String photoPath;
  final double size;
  final double radius;
  const ItemPhoto({
    super.key,
    required this.photoPath,
    this.size = 48,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath.isNotEmpty && File(photoPath).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: hasPhoto
          ? Image.file(
              File(photoPath),
              width: size,
              height: size,
              fit: BoxFit.cover,
            )
          : Image.asset(
              'assets/shepherd_icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
    );
  }
}

/// Wide variant for cards and grids: fills its width, fixed height.
class ItemPhotoWide extends StatelessWidget {
  final String photoPath;
  final double height;
  const ItemPhotoWide({super.key, required this.photoPath, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath.isNotEmpty && File(photoPath).existsSync();
    return hasPhoto
        ? Image.file(
            File(photoPath),
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          )
        : Image.asset(
            'assets/shepherd_icon.png',
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
          );
  }
}
