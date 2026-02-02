/// Flowr v2.0 - Chord Controller Library
/// 
/// A Flutter library for building chord-based MIDI controllers.
/// 
/// ## Core Concepts
/// 
/// - **Play Modes**: Songwriter (default), Explorer, Parallel
/// - **Songwriter Mode**: Pads are scale degrees, petal wheel overrides chord type
/// - **Explorer/Parallel Mode**: Petal wheel selects root, pads select chord type
/// 
/// ## Quick Start
/// 
/// ```dart
/// import 'package:flowr_v2/flowr_v2.dart';
/// 
/// final state = FlowrState();
/// 
/// // Set up MIDI callbacks
/// state.onMidiNote = (note, velocity, noteOn) {
///   // Send to your MIDI service
/// };
/// 
/// // Handle pad input
/// state.onPadDown(0);  // Play degree I chord
/// state.onPadUp(0);    // Release chord
/// 
/// // Handle petal input for chord type override
/// final petal = PetalLayout.getPetal(PetalRing.outer, 1);
/// state.onPetalDown(petal);  // Override to maj7
/// ```
/// 
/// ## Models
/// 
/// - [ChordRecipe] - Interval formulas for chord types
/// - [MusicalKey] - Key definitions with scale/chord logic
/// - [PadConfig] - Pad layout configuration
/// - [PetalConfig] - Petal wheel configuration
/// 
/// ## Services
/// 
/// - [FlowrState] - Main state manager
/// - [ChordBuilder] - Builds chords from key + degree + recipe
/// - [VoiceLeader] - Auto-voicing for smooth progressions
library flowr_v2;

export 'models/models.dart';
export 'services/services.dart';
