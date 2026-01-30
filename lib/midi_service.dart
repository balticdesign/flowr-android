import 'package:flutter/services.dart';
import 'dart:typed_data';

class MidiService {
  // USB MIDI channel
  static const _usbChannel = MethodChannel('com.petals/midi');
  // Virtual MIDI channel
  static const _virtualChannel = MethodChannel('flowr/midi_virtual');
  
  bool _usbConnected = false;
  bool _virtualEnabled = true; // Always enabled once service starts
  
  bool get isUsbConnected => _usbConnected;
  bool get isVirtualEnabled => _virtualEnabled;
  bool get isConnected => _usbConnected || _virtualEnabled;

  Future<void> checkConnection() async {
    try {
      final result = await _usbChannel.invokeMethod('isConnected');
      _usbConnected = result == true;
    } catch (e) {
      _usbConnected = false;
    }
  }

  /// Send MIDI to both USB and Virtual outputs
  void _sendMidiData(List<int> data) {
    final bytes = Uint8List.fromList(data);
    
    // Send via USB
    if (_usbConnected) {
      _usbChannel.invokeMethod('sendMidi', {'data': bytes});
    }
    
    // Send via Virtual MIDI (to other apps on same device)
    if (_virtualEnabled) {
      _virtualChannel.invokeMethod('sendMidi', bytes);
    }
  }

  void sendNoteOn(int note, int velocity, {int channel = 0}) {
    final status = 0x90 | (channel & 0x0F);
    _sendMidiData([status, note & 0x7F, velocity & 0x7F]);
  }

  void sendNoteOff(int note, {int channel = 0}) {
    final status = 0x80 | (channel & 0x0F);
    _sendMidiData([status, note & 0x7F, 0]);
  }

  void sendCC(int controller, int value, {int channel = 0}) {
    final status = 0xB0 | (channel & 0x0F);
    _sendMidiData([status, controller & 0x7F, value & 0x7F]);
  }

  void sendChordOn(List<int> notes, int velocity, {int channel = 0}) {
    for (final note in notes) {
      sendNoteOn(note, velocity, channel: channel);
    }
  }

  void sendChordOff(List<int> notes, {int channel = 0}) {
    for (final note in notes) {
      sendNoteOff(note, channel: channel);
    }
  }

  void dispose() {}
}