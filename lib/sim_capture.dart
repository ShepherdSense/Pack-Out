import 'package:flutter/material.dart';

import 'branding.dart';
import 'sim_store.dart';
import 'theme.dart';

/// The web sim's stand-in for the real CapturePhotoScreen: browsers in a demo
/// don't get the station's camera, so "taking" an equipment photo means
/// picking from the sim's preset photo set. Same contract as the real
/// screen — pops with a photo path (an 'asset://' pseudo-path), or null
/// when cancelled. Labeled SIMULATED CAMERA so nobody mistakes it for
/// a live viewfinder.
class SimCaptureScreen extends StatelessWidget {
  final String title;
  const SimCaptureScreen({super.key, this.title = 'Photograph the equipment'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: shepherdAppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: kText)),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.videocam_off, size: 16, color: kPurpleLight),
                  SizedBox(width: 6),
                  Text(
                    'SIMULATED CAMERA — pick the photo this gear gets',
                    style: TextStyle(
                      color: kPurpleLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: simGearPhotos.length + 1,
                  itemBuilder: (context, i) {
                    if (i == simGearPhotos.length) {
                      // The "no photo" choice: the item wears the
                      // Shepherd mark, exactly like a real item whose
                      // portrait hasn't been taken yet.
                      return _choice(
                        context,
                        photoPath: '',
                        label: 'No photo — Shepherd mark',
                        onTap: () => Navigator.of(context).pop(''),
                      );
                    }
                    final (asset, label) = simGearPhotos[i];
                    return _choice(
                      context,
                      photoPath: 'asset://$asset',
                      label: label,
                      onTap: () =>
                          Navigator.of(context).pop('asset://$asset'),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(
    BuildContext context, {
    required String photoPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: kCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: ItemPhotoWide(photoPath: photoPath, height: 140),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: kText, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
