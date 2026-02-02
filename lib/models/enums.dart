/// Play mode determines the control mapping
enum PlayMode {
  songwriter,
  explorer,
  parallel,
}

extension PlayModeInfo on PlayMode {
  String get label {
    switch (this) {
      case PlayMode.songwriter:
        return 'Songwriter';
      case PlayMode.explorer:
        return 'Explorer';
      case PlayMode.parallel:
        return 'Parallel';
    }
  }

  String get description {
    switch (this) {
      case PlayMode.songwriter:
        return 'Play diatonic chords in any key. Pads are scale degrees, wheel overrides chord type.';
      case PlayMode.explorer:
        return 'Circle of fifths layout. Learn key relationships and access every chord.';
      case PlayMode.parallel:
        return 'Chromatic root selection. Direct access to all 12 major and minor keys.';
    }
  }

  String get shortDescription {
    switch (this) {
      case PlayMode.songwriter:
        return 'Pads = degrees, Wheel = chord type';
      case PlayMode.explorer:
        return 'Wheel = circle of fifths';
      case PlayMode.parallel:
        return 'Wheel = chromatic roots';
    }
  }
}

/// Petal ring selection
enum PetalRing {
  outer,
  inner,
}

/// Pad type for the 9-pad layout
enum PadType {
  degree,
  function,
  sustain,
}

/// Scale degree (1-7)
enum ScaleDegree {
  i(1, 'I'),
  ii(2, 'ii'),
  iii(3, 'iii'),
  iv(4, 'IV'),
  v(5, 'V'),
  vi(6, 'vi'),
  vii(7, 'vii°');

  final int number;
  final String symbol;

  const ScaleDegree(this.number, this.symbol);

  /// Get degree from pad index (0-6)
  static ScaleDegree fromPadIndex(int index) {
    return ScaleDegree.values[index.clamp(0, 6)];
  }
}
