package com.yadvi.unified_app

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.yadvi.unified_app/file_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "savePdfToDownloads") {
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")

                if (bytes == null || fileName == null) {
                    result.error("INVALID_ARGS", "bytes and fileName are required", null)
                    return@setMethodCallHandler
                }

                try {
                    val savedPath = savePdfToDownloads(applicationContext, bytes, fileName)
                    result.success(mapOf(
                        "success" to true,
                        "path" to savedPath,
                        "fileName" to fileName
                    ))
                } catch (e: Exception) {
                    result.error("SAVE_FAILED", e.localizedMessage ?: "Failed to save PDF", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun savePdfToDownloads(context: Context, bytes: ByteArray, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

            // Remove existing entry with identical name if created by this app to prevent confusing (1) duplicates
            try {
                val projection = arrayOf(MediaStore.Downloads._ID)
                val selection = "${MediaStore.Downloads.DISPLAY_NAME} = ?"
                val selectionArgs = arrayOf(fileName)
                resolver.query(collection, projection, selection, selectionArgs, null)?.use { cursor ->
                    val idCol = cursor.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                    while (cursor.moveToNext()) {
                        val id = cursor.getLong(idCol)
                        val itemUri = Uri.withAppendedPath(collection, id.toString())
                        resolver.delete(itemUri, null, null)
                    }
                }
            } catch (_: Exception) {
                // Ignore query/delete errors and proceed with insertion
            }

            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val itemUri = resolver.insert(collection, contentValues)
                ?: throw IllegalStateException("Could not create MediaStore entry for $fileName")

            try {
                resolver.openOutputStream(itemUri)?.use { os ->
                    os.write(bytes)
                    os.flush()
                } ?: throw IllegalStateException("Could not open output stream for $itemUri")

                contentValues.clear()
                contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(itemUri, contentValues, null, null)
            } catch (e: Exception) {
                try { resolver.delete(itemUri, null, null) } catch (_: Exception) {}
                throw e
            }

            return itemUri.toString()
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloadsDir.exists()) {
                downloadsDir.mkdirs()
            }
            val targetFile = File(downloadsDir, fileName)
            FileOutputStream(targetFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }

            MediaScannerConnection.scanFile(
                context,
                arrayOf(targetFile.absolutePath),
                arrayOf("application/pdf"),
                null
            )

            return targetFile.absolutePath
        }
    }
}
