import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Shared preference key for which camera the station prefers for
/// equipment photos: 'front' or 'back'. The capture screen's flip button
/// and the staff Settings page both read/write it, so the choice sticks.
const cameraPrefKey = 'camera_pref';

Future<CameraLensDirection> preferredLens() async {
  final prefs = await SharedPreferences.getInstance();
  return (prefs.getString(cameraPrefKey) ?? 'back') == 'front'
      ? CameraLensDirection.front
      : CameraLensDirection.back;
}

Future<void> savePreferredLens(CameraLensDirection dir) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      cameraPrefKey, dir == CameraLensDirection.front ? 'front' : 'back');
}

/// Boolean view of the preference for the Settings page (true = front).
Future<bool> preferredCamFront() async =>
    (await preferredLens()) == CameraLensDirection.front;

Future<void> saveCamFront(bool front) => savePreferredLens(
    front ? CameraLensDirection.front : CameraLensDirection.back);

/// Full-screen "photograph the equipment" screen. Either camera works —
/// the flip button switches lenses and remembers the choice. Pops with
/// the captured file's path, or null when cancelled.
class CapturePhotoScreen extends StatefulWidget {
  final String title;
  const CapturePhotoScreen(
      {super.key, this.title = 'Photograph the equipment'});

  @override
  State<CapturePhotoScreen> createState() => _CapturePhotoScreenState();
}

class _CapturePhotoScreenState extends State<CapturePhotoScreen> {
  List<CameraDescription> _cams = [];
  CameraController? _cam;
  CameraLensDirection _lens = CameraLensDirection.back;
  bool _ready = false;
  bool _busy = false;
  // Camera starts are serialized by generation: a flip during a slow
  // first init (normal on this tablet) must not run two starts at once
  // and leak a controller that keeps holding the camera.
  bool _starting = false;
  int _startGen = 0;
  // Set the moment this screen starts leaving, so a late takePicture
  // completion can never pop whatever is underneath.
  bool _popped = false;
  String _status = 'Starting camera…';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        if (mounted) setState(() => _status = 'No camera found on this tablet.');
        return;
      }
      _lens = await preferredLens();
      await _start(_lens);
    } catch (_) {
      if (mounted) setState(() => _status = 'Camera unavailable.');
    }
  }

  Future<void> _start(CameraLensDirection dir) async {
    final gen = ++_startGen;
    _starting = true;
    final old = _cam;
    _cam = null;
    if (mounted) setState(() => _ready = false);
    await old?.dispose();
    try {
      final desc = _cams.firstWhere(
        (c) => c.lensDirection == dir,
        orElse: () => _cams.first,
      );
      final ctl = CameraController(desc, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await ctl.initialize();
      if (!mounted || gen != _startGen) {
        // A newer start superseded this one — hand the camera back.
        await ctl.dispose();
        return;
      }
      _lens = desc.lensDirection;
      // Persist the lens choice only AFTER it actually started — a
      // failed lens must not become the remembered default.
      await savePreferredLens(_lens);
      setState(() {
        _cam = ctl;
        _ready = true;
        _status = 'Fill the frame with the equipment, then tap the shutter';
      });
    } catch (_) {
      if (mounted && gen == _startGen) {
        setState(() => _status = 'Camera unavailable.');
      }
    } finally {
      if (gen == _startGen) _starting = false;
    }
  }

  bool get _canFlip =>
      _cams.any((c) => c.lensDirection != _lens) && _cams.length > 1;

  Future<void> _flip() async {
    if (!_canFlip || _busy || _starting) return;
    final next = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    await _start(next);
  }

  Future<void> _shoot() async {
    final ctl = _cam;
    if (ctl == null || !ctl.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await ctl.takePicture();
      if (!mounted || _popped) return;
      _popped = true;
      Navigator.of(context).pop(shot.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'That shot failed — try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _popped = true;
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_ready && _cam != null)
                  CameraPreview(_cam!)
                else
                  const Center(child: CircularProgressIndicator()),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 6, color: Colors.black)]),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: kBg,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // Disabled mid-shot: cancelling while takePicture is
                    // in flight risks a double-pop into the screen below.
                    onPressed: _busy
                        ? null
                        : () {
                            _popped = true;
                            Navigator.of(context).pop(null);
                          },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _ready && !_busy ? _shoot : null,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(_busy ? 'One sec…' : 'Take photo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canFlip ? _flip : null,
                    icon: const Icon(Icons.flip_camera_android),
                    label: Text(
                        _lens == CameraLensDirection.back ? 'Front' : 'Back'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
