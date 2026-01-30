package io.getflowr.flowr

import android.content.Intent
import android.media.midi.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // USB MIDI channel (existing)
    private val USB_CHANNEL = "com.petals/midi"
    // Virtual MIDI channel (new)
    private val VIRTUAL_CHANNEL = "flowr/midi_virtual"
    
    private var midiManager: MidiManager? = null
    private var midiDevice: MidiDevice? = null
    private var inputPort: MidiInputPort? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        midiManager = getSystemService(Context.MIDI_SERVICE) as MidiManager
        
        // Warm up the virtual MIDI service
        warmUpMidiService()
        
        // USB MIDI channel (existing functionality)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USB_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMidi" -> {
                    val data = call.argument<ByteArray>("data")
                    if (data != null) {
                        sendUsbMidiData(data)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data is null", null)
                    }
                }
                "isConnected" -> {
                    result.success(inputPort != null)
                }
                "reconnect" -> {
                    connectToUsbDevice()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Virtual MIDI channel (new functionality)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIRTUAL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendMidi" -> {
                    val bytes: ByteArray? = call.arguments as? ByteArray
                    if (bytes == null) {
                        result.error("BAD_ARGS", "Expected Uint8List/ByteArray", null)
                        return@setMethodCallHandler
                    }
                    FlowrMidiDeviceService.sendToOutputPort0(bytes)
                    result.success(true)
                }
                "isEnabled" -> {
                    // Service is always available once warmed up
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        connectToUsbDevice()
        
        midiManager?.registerDeviceCallback(object : MidiManager.DeviceCallback() {
            override fun onDeviceAdded(device: MidiDeviceInfo) {
                if (inputPort == null) {
                    connectToUsbDevice()
                }
            }
            
            override fun onDeviceRemoved(device: MidiDeviceInfo) {
                if (midiDevice?.info == device) {
                    inputPort?.close()
                    inputPort = null
                    midiDevice?.close()
                    midiDevice = null
                }
            }
        }, Handler(Looper.getMainLooper()))
    }
    
    private fun warmUpMidiService() {
        val intent = Intent(this, FlowrMidiDeviceService::class.java)
        startService(intent)
    }
    
    private fun connectToUsbDevice() {
        val devices = midiManager?.devices ?: return
        
        for (deviceInfo in devices) {
            // Skip virtual/software MIDI devices - only connect to USB hardware
            val type = deviceInfo.type
            if (type != MidiDeviceInfo.TYPE_USB) {
                continue
            }
            
            if (deviceInfo.inputPortCount > 0) {
                midiManager?.openDevice(deviceInfo, { device ->
                    if (device != null) {
                        midiDevice = device
                        val portInfo = deviceInfo.ports.find { it.type == MidiDeviceInfo.PortInfo.TYPE_INPUT }
                        if (portInfo != null) {
                            inputPort = device.openInputPort(portInfo.portNumber)
                        }
                    }
                }, Handler(Looper.getMainLooper()))
                break
            }
        }
    }
    
    private fun sendUsbMidiData(data: ByteArray) {
        inputPort?.send(data, 0, data.size)
    }
    
    override fun onDestroy() {
        inputPort?.close()
        midiDevice?.close()
        super.onDestroy()
    }
}