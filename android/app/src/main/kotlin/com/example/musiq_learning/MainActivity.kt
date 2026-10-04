package com.example.musiq_learning

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val SONG_FILE_CHANNEL = "musiq_learning/song_files"
private const val PICK_AUDIO_REQUEST = 4107

class MainActivity : FlutterActivity() {
    private var pendingPickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SONG_FILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAudioFile" -> openAudioPicker(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun openAudioPicker(result: MethodChannel.Result) {
        if (pendingPickerResult != null) {
            result.error("picker_in_progress", "An audio picker is already open.", null)
            return
        }
        pendingPickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
        }
        try {
            startActivityForResult(intent, PICK_AUDIO_REQUEST)
        } catch (error: Exception) {
            pendingPickerResult = null
            result.error("picker_unavailable", error.message, null)
        }
    }

    @Deprecated("The document picker result is delivered through this activity callback.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_AUDIO_REQUEST) return

        val result = pendingPickerResult
        pendingPickerResult = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        try {
            result.success(copyPickedAudioToCache(uri))
        } catch (error: Exception) {
            result.error("audio_import_failed", error.message, null)
        }
    }

    private fun copyPickedAudioToCache(uri: Uri): Map<String, Any?> {
        val resolver = contentResolver
        val fileName = queryDisplayName(uri) ?: "song_audio"
        val mimeType = resolver.getType(uri) ?: "application/octet-stream"
        val extension = fileName.substringAfterLast('.', "")
            .takeIf { it.matches(Regex("[A-Za-z0-9]{1,8}")) }
            ?: mimeType.substringAfter('/', "audio").replace(Regex("[^A-Za-z0-9]"), "")
                .take(8).ifEmpty { "audio" }

        val songDirectory = File(cacheDir, "song_uploads").apply { mkdirs() }
        val copiedFile = File(songDirectory, "${System.currentTimeMillis()}.$extension")
        val input = resolver.openInputStream(uri)
            ?: throw IllegalStateException("The selected audio file could not be opened.")
        input.use { source ->
            copiedFile.outputStream().use { output -> source.copyTo(output) }
        }

        val durationMs = readDurationMs(copiedFile)
        return mapOf(
            "path" to copiedFile.absolutePath,
            "fileName" to fileName,
            "mimeType" to mimeType,
            "durationMs" to durationMs,
        )
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, null, null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameColumn >= 0) cursor.getString(nameColumn) else null
            } else null
        } finally {
            cursor?.close()
        }
    }

    private fun readDurationMs(file: File): Long {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                ?.toLongOrNull() ?: 0L
        } catch (_: Exception) {
            0L
        } finally {
            retriever.release()
        }
    }
}
