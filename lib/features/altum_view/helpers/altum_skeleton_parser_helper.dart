// ─────────────────────────────────────────────────────────────────────────────
// altum_alert_skeleton_parser.dart
//
// Parses the skeleton_file field from GET /alerts/:id
//
// IMPORTANT — this format is COMPLETELY different from the live MQTT stream:
//
//   Live stream:   float32 coordinates  (0.0 – 1.0)
//   Alert file:    int16 fixed-point    (divided by screenWidth/Height to get 0–1)
//
// Alert binary format (SH-alert_binary_format_v3.pdf):
//
// ┌─────────────────────────── ALERT HEADER (28 bytes) ────────────────────┐
// │ [0..3]   uint32  version flag                                          │
// │ [4..7]   uint32  epoch time (unix timestamp)                           │
// │ [8..11]  int32   personId                                              │
// │ [12]     uint8   skeletonConfidence                                    │
// │ [13..15] uint8×3 padding (skip)                                        │
// │ [16..17] uint16  screenWidth                                           │
// │ [18..19] uint16  screenHeight                                          │
// │ [20..21] int16   x (bounding box or skeleton X position)              │
// │ [22..23] int16   y                                                     │
// │ [24]     uint8   event type                                            │
// │ [25]     uint8   level                                                 │
// │ [26..27] int16   numFrames  ← how many frames follow                  │
// └────────────────────────────────────────────────────────────────────────┘
//
// Then numFrames × FRAME blocks (frames are in REVERSED order — newest first):
//
// ┌─────────────────────── FRAME HEADER (18 bytes) ────────────────────────┐
// │ [0..1]  uint16   msDelta (milliseconds since alert start)              │
// │ [2]     uint8    action label (0=standing,1=sitting,2=lying,etc.)      │
// │ [3]     uint8    numKeyPoints (usually 18)                             │
// │ [4..11] int16×4  bounding box: x0,y0,x1,y1                            │
// │ [10..17] uint8×7 action probabilities + 1 padding byte                │
// └────────────────────────────────────────────────────────────────────────┘
//
// Then numKeyPoints × KEY POINT structs (6 bytes each):
//
// ┌──────────────────────── KEY POINT (6 bytes) ───────────────────────────┐
// │ [0]     uint8   keyPointIndex (which joint: 0=Nose, 1=Neck, etc.)      │
// │ [1]     uint8   keyPointProb  (confidence 0-255 → divide by 255)       │
// │ [2..3]  int16   X  (fixed point: divide by screenWidth  to get 0–1)    │
// │ [4..5]  int16   Y  (divide by screenHeight to get 0–1)                 │
// └────────────────────────────────────────────────────────────────────────┘
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

/// One joint in an alert skeleton frame.
class AlertJoint {
  final int    index;       // 0–17 (same joint map as live stream)
  final double x;           // normalized 0.0 – 1.0
  final double y;           // normalized 0.0 – 1.0
  final double confidence;  // 0.0 – 1.0

  const AlertJoint({
    required this.index,
    required this.x,
    required this.y,
    required this.confidence,
  });
}

/// One frame in an alert skeleton animation.
class AlertFrame {
  final int              msDelta;    // ms since alert start — use for playback timing
  final int              action;     // action label (0=unknown, 2=lying=fallen, etc.)
  final List<AlertJoint> joints;     // up to 18 joints

  const AlertFrame({
    required this.msDelta,
    required this.action,
    required this.joints,
  });
}

/// Full parsed alert skeleton, ready for playback.
class ParsedAlertSkeleton {
  final int              personId;
  final int              screenWidth;
  final int              screenHeight;
  final int              numFrames;
  final List<AlertFrame> frames;     // already in CORRECT order (oldest → newest)
  final Duration         totalDuration;

  const ParsedAlertSkeleton({
    required this.personId,
    required this.screenWidth,
    required this.screenHeight,
    required this.numFrames,
    required this.frames,
    required this.totalDuration,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// PARSER
// ═════════════════════════════════════════════════════════════════════════════

class AltumAlertSkeletonParser {
  /// Pass in the raw Base64 string from alert.skeleton_file
  static ParsedAlertSkeleton? parse(String base64String) {
    try {
      final bytes = base64Decode(base64String);
      return _parseBytes(Uint8List.fromList(bytes));
    } catch (e) {
      log('❌ AlertSkeletonParser: $e');
      return null;
    }
  }

  static ParsedAlertSkeleton? _parseBytes(Uint8List bytes) {
    if (bytes.length < 28) {
      log('⚠️ Alert skeleton too short: ${bytes.length} bytes');
      return null;
    }

    final bd = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes);

    // ── Alert header (28 bytes) ─────────────────────────────────────────────
    final version      = bd.getUint32(0,  Endian.little);
    // [4..7]  epoch time — skip for now
    final personId     = bd.getInt32 (8,  Endian.little);
    // [12]    skeletonConfidence — skip
    // [13-15] padding — skip
    final screenWidth  = bd.getUint16(16, Endian.little);
    final screenHeight = bd.getUint16(18, Endian.little);
    // [20-23] x, y position — skip
    // [24]    event type — skip
    // [25]    level — skip
    final numFrames    = bd.getInt16 (26, Endian.little);

    log('📽️ Alert skeleton v$version  personId=$personId '
        'screen=${screenWidth}x$screenHeight  frames=$numFrames');

    if (numFrames <= 0 || numFrames > 10000) {
      log('⚠️ numFrames=$numFrames looks invalid');
      return null;
    }

    // Use sensible defaults if screen dimensions are zero
    final w = screenWidth  > 0 ? screenWidth  : 1920;
    final h = screenHeight > 0 ? screenHeight : 1080;

    // ── Parse frames ────────────────────────────────────────────────────────
    // Frames start at byte 28 and are stored in REVERSED order (newest first).
    // We parse them all then reverse so index 0 = oldest frame.

    final rawFrames = <AlertFrame>[];
    int offset = 28;

    for (int f = 0; f < numFrames; f++) {
      if (offset + 18 > bytes.length) {
        log('⚠️ Frame $f out of bounds at offset $offset');
        break;
      }

      // Frame header (18 bytes)
      final msDelta      = bd.getUint16(offset,     Endian.little);
      final action       = bd.getUint8 (offset + 2);
      final numKeyPoints = bd.getUint8 (offset + 3);
      // [+4..+11] bounding box (8 bytes) — skip for now
      // [+10..+17] action probs (8 bytes) — skip for now
      offset += 18;

      // Key points
      final joints = <AlertJoint>[];
      for (int k = 0; k < numKeyPoints; k++) {
        if (offset + 6 > bytes.length) break;

        final kpIndex = bd.getUint8(offset);
        final kpProb  = bd.getUint8(offset + 1);
        final kpX     = bd.getInt16(offset + 2, Endian.little);
        final kpY     = bd.getInt16(offset + 4, Endian.little);
        offset += 6;

        // Normalize fixed-point coordinates to 0.0 – 1.0
        final normX = (kpX / w).clamp(0.0, 1.0);
        final normY = (kpY / h).clamp(0.0, 1.0);
        final conf  = kpProb / 255.0;

        joints.add(AlertJoint(
          index:      kpIndex,
          x:          normX,
          y:          normY,
          confidence: conf,
        ));
      }

      rawFrames.add(AlertFrame(msDelta: msDelta, action: action, joints: joints));
    }

    // Reverse frames: alert binary stores newest-first, we want oldest-first
    final frames = rawFrames.reversed.toList();

    final totalMs = frames.isNotEmpty ? frames.last.msDelta : 0;

    log('✅ Parsed ${frames.length} frames  duration=${totalMs}ms');

    return ParsedAlertSkeleton(
      personId:      personId,
      screenWidth:   w,
      screenHeight:  h,
      numFrames:     frames.length,
      frames:        frames,
      totalDuration: Duration(milliseconds: totalMs),
    );
  }
}