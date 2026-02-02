import 'package:flutter/services.dart';
import 'dart:typed_data';

enum MidiOutputMode {
  apps,      // Virtual MIDI to other apps on same device (AND to PC via USB!)
  external,  // Direct USB host mode (for hardware synths via OTG)
}

class MidiService {
  // USB MIDI channel (for USB HOST mode - phone connecting TO hardware synth)
  static const _usbChannel = MethodChannel('com.petals/midi');
  // Virtual MIDI channel (FlowrMidiDeviceService - works for apps AND PC via USB gadget)
  static const _virtualChannel = MethodChannel('flowr/midi_virtual');
  
  bool _usbConnected = false;
  
  // Output mode - defaults to apps
  MidiOutputMode _outputMode = MidiOutputMode.apps;
  
  bool get isUsbConnected => _usbConnected;
  MidiOutputMode get outputMode => _outputMode;
  
  bool get isConnected => true;
  
  String get connectionStatusText {
    switch (_outputMode) {
      case MidiOutputMode.apps:
        return 'MIDI Active (Apps/PC)';
      case MidiOutputMode.external:
        return _usbConnected ? 'Hardware Connected' : 'No Hardware Found';
    }
  }

  void setOutputMode(MidiOutputMode mode) {
    _outputMode = mode;
  }

  Future<void> checkConnection() async {
    try {
      final result = await _usbChannel.invokeMethod('isConnected');
      _usbConnected = result == true;
    } catch (e) {
      _usbConnected = false;
    }
  }
  
  Future<void> reconnectUsb() async {
    try {
      await _usbChannel.invokeMethod('reconnect');
      await checkConnection();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Send MIDI based on current output mode
  void _sendMidiData(List<int> data) {
    final bytes = Uint8List.fromList(data);
    
    switch (_outputMode) {
      case MidiOutputMode.apps:
        // Virtual channel handles BOTH on-device apps AND USB to PC!
        // This is what your original did and it worked
        _virtualChannel.invokeMethod('sendMidi', bytes);
        break;
        
      case MidiOutputMode.external:
        // USB host mode - for connecting hardware synth TO phone via OTG
        // Only use this when you have a synth plugged into the phone
        if (_usbConnected) {
          _usbChannel.invokeMethod('sendMidi', {'data': bytes});
        }
        break;
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
  
  void sendSustainOn({int channel = 0}) {
    sendCC(64, 127, channel: channel);
  }
  
  void sendSustainOff({int channel = 0}) {
    sendCC(64, 0, channel: channel);
  }

  void dispose() {}
}