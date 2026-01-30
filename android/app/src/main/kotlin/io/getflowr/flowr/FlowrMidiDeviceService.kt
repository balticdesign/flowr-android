package io.getflowr.flowr

import android.media.midi.MidiDeviceService
import android.media.midi.MidiReceiver
import android.util.Log
import java.util.concurrent.atomic.AtomicReference

class FlowrMidiDeviceService : MidiDeviceService() {

    companion object {
        private const val TAG = "FlowrMidiDeviceService"

        // Keep a process-local reference so MainActivity/Flutter can send without binding.
        private val INSTANCE = AtomicReference<FlowrMidiDeviceService?>()

        /**
         * Send raw MIDI bytes out of OUTPUT port 0 (the port other apps connect to).
         */
        fun sendToOutputPort0(data: ByteArray, offset: Int = 0, count: Int = data.size, timestampNanos: Long = 0L) {
            val service = INSTANCE.get()
            if (service == null) {
                Log.w(TAG, "Service not running yet; dropping MIDI (${count} bytes).")
                return
            }
            service.sendInternal(port = 0, data = data, offset = offset, count = count, timestampNanos = timestampNanos)
        }
    }

    // One Dummy input ports - we only send MIDI out
    override fun onGetInputPortReceivers(): Array<MidiReceiver> {
    return arrayOf(object : MidiReceiver() {
        override fun onSend(
            data: ByteArray,
            offset: Int,
            count: Int,
            timestamp: Long
        ) {
            // Intentionally ignored
        }
    })
}

    override fun onCreate() {
        super.onCreate()
        INSTANCE.set(this)
        Log.i(TAG, "Created; output ports available to other apps.")
    }

    override fun onDestroy() {
        INSTANCE.compareAndSet(this, null)
        super.onDestroy()
        Log.i(TAG, "Destroyed.")
    }

    private fun sendInternal(port: Int, data: ByteArray, offset: Int, count: Int, timestampNanos: Long) {
        try {
            val outputs = outputPortReceivers
            if (port < 0 || port >= outputs.size) {
                Log.w(TAG, "Invalid output port index $port (have ${outputs.size}).")
                return
            }
            outputs[port].send(data, offset, count, timestampNanos)
        } catch (t: Throwable) {
            Log.e(TAG, "Failed to send MIDI", t)
        }
    }
}