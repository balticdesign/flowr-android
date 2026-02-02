import '../models/enums.dart';

/// Configuration for a single pad
class PadConfig {
  /// Pad index (0-8)
  final int index;

  /// Type of pad
  final PadType type;

  /// Scale degree (only for degree pads)
  final ScaleDegree? degree;

  /// Display label
  final String label;

  /// Short label for compact display
  final String shortLabel;

  const PadConfig({
    required this.index,
    required this.type,
    this.degree,
    required this.label,
    required this.shortLabel,
  });

  /// Is this a playable chord pad?
  bool get isChordPad => type == PadType.degree;

  /// Is this the function pad?
  bool get isFunctionPad => type == PadType.function;

  /// Is this the sustain pad?
  bool get isSustainPad => type == PadType.sustain;
}

/// Layout configuration for all 9 pads
class PadLayout {
  // Prevent instantiation
  PadLayout._();

  /// Standard 3x3 layout for Songwriter mode:
  /// ```
  /// [  I  ] [ ii  ] [FUNC ]
  /// [ iii ] [ IV  ] [  V  ]
  /// [ vi  ] [vii° ] [HOLD ]
  /// ```
  static const songwriterLayout = [
    // Row 1
    PadConfig(
      index: 0,
      type: PadType.degree,
      degree: ScaleDegree.i,
      label: 'I',
      shortLabel: 'I',
    ),
    PadConfig(
      index: 1,
      type: PadType.degree,
      degree: ScaleDegree.ii,
      label: 'ii',
      shortLabel: 'ii',
    ),
    PadConfig(
      index: 2,
      type: PadType.function,
      label: 'FUNC',
      shortLabel: '⚙',
    ),
    // Row 2
    PadConfig(
      index: 3,
      type: PadType.degree,
      degree: ScaleDegree.iii,
      label: 'iii',
      shortLabel: 'iii',
    ),
    PadConfig(
      index: 4,
      type: PadType.degree,
      degree: ScaleDegree.iv,
      label: 'IV',
      shortLabel: 'IV',
    ),
    PadConfig(
      index: 5,
      type: PadType.degree,
      degree: ScaleDegree.v,
      label: 'V',
      shortLabel: 'V',
    ),
    // Row 3
    PadConfig(
      index: 6,
      type: PadType.degree,
      degree: ScaleDegree.vi,
      label: 'vi',
      shortLabel: 'vi',
    ),
    PadConfig(
      index: 7,
      type: PadType.degree,
      degree: ScaleDegree.vii,
      label: 'vii°',
      shortLabel: 'vii°',
    ),
    PadConfig(
      index: 8,
      type: PadType.sustain,
      label: 'HOLD',
      shortLabel: '⏸',
    ),
  ];

  /// Get pad config by index
  static PadConfig getPad(int index) {
    return songwriterLayout[index.clamp(0, 8)];
  }

  /// Get all chord pads (degrees only)
  static List<PadConfig> get chordPads {
    return songwriterLayout.where((p) => p.isChordPad).toList();
  }

  /// Get the function pad
  static PadConfig get functionPad {
    return songwriterLayout.firstWhere((p) => p.isFunctionPad);
  }

  /// Get the sustain pad
  static PadConfig get sustainPad {
    return songwriterLayout.firstWhere((p) => p.isSustainPad);
  }

  /// Get pad index for a scale degree (1-7)
  static int? indexForDegree(int degree) {
    for (final pad in songwriterLayout) {
      if (pad.degree?.number == degree) {
        return pad.index;
      }
    }
    return null;
  }

  /// Get scale degree for a pad index (null if not a chord pad)
  static int? degreeForIndex(int index) {
    final pad = getPad(index);
    return pad.degree?.number;
  }

  /// Number of rows
  static const int rows = 3;

  /// Number of columns
  static const int columns = 3;

  /// Total number of pads
  static const int totalPads = 9;
}
