# Flowr v2.0 - Chord Controller Library

A Flutter/Dart library for building chord-based MIDI controllers with intelligent voice leading.

## Features

- **Three Play Modes**
  - **Songwriter** (default): Pads = scale degrees, wheel = chord types
  - **Explorer**: Circle of fifths layout for learning key relationships
  - **Parallel**: Chromatic root selection

- **Smart Voice Leading**: Inner petal ring automatically selects inversions for smooth chord progressions

- **12 Chord Types**: Major, Minor, Maj7, m7, Dom7, Maj9, m9, Add9, Sus2, Sus4, Dim, Aug

- **Full Key Support**: All 12 major and 12 minor keys

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flowr_v2:
    path: ./flowr_v2  # Or your path
```

## Quick Start

```dart
import 'package:flowr_v2/flowr_v2.dart';

// Create the state manager
final state = FlowrState();

// Set up MIDI callbacks
state.onMidiNote = (note, velocity, noteOn) {
  if (noteOn) {
    midiService.noteOn(note, velocity);
  } else {
    midiService.noteOff(note);
  }
};

state.onMidiCC = (cc, value) {
  midiService.sendCC(cc, value);
};

// Handle pad presses (in your UI)
void onPadPressed(int index) => state.onPadDown(index);
void onPadReleased(int index) => state.onPadUp(index);

// Handle petal touches (in your UI)
void onPetalTouched(double x, double y) {
  final petal = PetalLayout.petalFromCartesian(x, y);
  if (petal != null) {
    state.onPetalDown(petal);
  }
}

void onPetalReleased() => state.onPetalUp();
```

## Architecture

### Pad Layout (Songwriter Mode)

```
┌─────────┬─────────┬─────────┐
│    I    │   ii    │  FUNC   │
├─────────┼─────────┼─────────┤
│   iii   │   IV    │    V    │
├─────────┼─────────┼─────────┤
│   vi    │  vii°   │  HOLD   │
└─────────┴─────────┴─────────┘
```

### Petal Wheel (24 petals)

- **Outer ring (12)**: Chord types, root position
- **Inner ring (12)**: Same chord types, auto-voiced inversions

Clockwise from 12 o'clock:
1. Major
2. Maj7
3. Maj9
4. Add9
5. 6
6. Sus2
7. m7
8. m9
9. Sus4
10. Dom7
11. Dim
12. Aug

### Key Selection

Hold FUNC pad + touch petal:
- Outer ring = Major key
- Inner ring = Minor key (parallel)

## API Reference

### FlowrState

Main state manager. Handles all input and generates MIDI output.

```dart
// Properties
PlayMode playMode
MusicalKey currentKey
int baseOctave
BuiltChord? currentChord
bool sustainActive

// Methods
void setPlayMode(PlayMode mode)
void setKey(MusicalKey key)
void onPadDown(int index)
void onPadUp(int index)
void onPetalDown(PetalConfig petal)
void onPetalUp()
void panic()  // All notes off
```

### ChordBuilder

Builds chords from key + degree + recipe.

```dart
final builder = ChordBuilder(key: MusicalKeys.cMajor);

// Build diatonic chord
final chord = builder.build(degree: 5);  // G major

// Build with override
final chord = builder.build(
  degree: 5,
  recipe: ChordRecipes.dom7,  // G7
);

// Build with auto-voicing
final chord = builder.build(
  degree: 5,
  autoVoice: true,
);
```

### VoiceLeader

Handles automatic chord voicing for smooth progressions.

```dart
final voiceLeader = VoiceLeader();

// Voice a C major chord
final c = voiceLeader.voice([0, 4, 7], 0);

// Voice a G major chord (will choose best inversion)
final g = voiceLeader.voice([7, 11, 2], 7);

// Reset context
voiceLeader.reset();
```

### ChordRecipes

All available chord types.

```dart
ChordRecipes.major      // [0, 4, 7]
ChordRecipes.minor      // [0, 3, 7]
ChordRecipes.maj7       // [0, 4, 7, 11]
ChordRecipes.min7       // [0, 3, 7, 10]
ChordRecipes.dom7       // [0, 4, 7, 10]
ChordRecipes.sus2       // [0, 2, 7]
ChordRecipes.sus4       // [0, 5, 7]
ChordRecipes.diminished // [0, 3, 6]
ChordRecipes.augmented  // [0, 4, 8]
// ... and more
```

### MusicalKeys

All available keys.

```dart
MusicalKeys.cMajor
MusicalKeys.gMajor
MusicalKeys.aMinor
// ... all 24 keys

// Get by petal position
MusicalKeys.byPetalChromatic(7, inner: false)  // G major
MusicalKeys.byPetalChromatic(7, inner: true)   // G minor
```

## Testing

```bash
flutter test
```

## License

MIT
