import 'dart:io';

import 'package:flutter/material.dart';

import 'store.dart';
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
        // The web sim labels itself wherever the banner rides — nobody
        // mistakes the browser demo for a live station. Inert on device.
        if (kPackOutSim) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: kPurpleLight),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'WEB SIM',
              style: TextStyle(
                color: kPurpleLight,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
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
    // Web-sim photos are bundled assets behind an 'asset://' pseudo-path
    // (dart:io Files don't exist in a browser). Real item photos are
    // absolute file paths and never carry the prefix.
    if (photoPath.startsWith('asset://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          photoPath.substring('asset://'.length),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/shepherd_icon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
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
    if (photoPath.startsWith('asset://')) {
      return Image.asset(
        photoPath.substring('asset://'.length),
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/shepherd_icon.png',
          width: double.infinity,
          height: height,
          fit: BoxFit.cover,
        ),
      );
    }
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
