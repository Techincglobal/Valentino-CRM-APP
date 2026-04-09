package com.example.crm_caller_nxtgen.overlay.recording

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.Environment
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Records microphone audio during a call and saves it as an M4A file.
 *
 * Note: Android does not allow third-party apps to capture the earpiece audio
 * (the remote caller's voice). VOICE_COMMUNICATION captures only the local
 * microphone, which is sufficient for call notes. Dual-channel recording
 * requires being the default dialer.
 *
 * Files are saved to:
 *   getExternalFilesDir(MUSIC)/CRM_Recordings/CRM_Call_<phone>_<timestamp>.m4a
 * No storage permission is required for this path on API 29+.
 */
class CallRecorder(private val context: Context) {

    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null

    val isRecording: Boolean get() = recorder != null

    /**
     * Start recording. Returns the output file path on success, null on failure.
     * Safe to call multiple times — subsequent calls are no-ops while recording.
     */
    fun startRecording(phoneNumber: String): String? {
        if (recorder != null) return outputFile?.absolutePath
        return try {
            val file = buildOutputFile(phoneNumber)
            outputFile = file
            recorder = buildRecorder(file.absolutePath).also {
                it.prepare()
                it.start()
            }
            file.absolutePath
        } catch (e: Exception) {
            recorder?.release()
            recorder = null
            outputFile = null
            null
        }
    }

    /**
     * Stop recording and finalise the file. Returns the saved file path, or null if not recording.
     */
    fun stopRecording(): String? {
        if (recorder == null) return null
        return try {
            recorder?.apply {
                stop()
                release()
            }
            recorder = null
            outputFile?.absolutePath.also { outputFile = null }
        } catch (_: Exception) {
            recorder?.release()
            recorder = null
            outputFile = null
            null
        }
    }

    private fun buildOutputFile(phone: String): File {
        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val safePhone = phone.replace(Regex("[^0-9+]"), "")
        val fileName = "CRM_Call_${safePhone}_${timestamp}.m4a"
        val dir = File(
            context.getExternalFilesDir(Environment.DIRECTORY_MUSIC),
            "CRM_Recordings"
        )
        dir.mkdirs()
        return File(dir, fileName)
    }

    private fun buildRecorder(outputPath: String): MediaRecorder {
        val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        return rec.apply {
            setAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioSamplingRate(44100)
            setAudioEncodingBitRate(128_000)
            setOutputFile(outputPath)
        }
    }
}
