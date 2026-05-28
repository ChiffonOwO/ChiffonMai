package com.example.my_first_flutter_app

import android.content.ContentValues
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveImage") {
                val imageBytes = call.argument<ByteArray>("imageBytes")
                val fileName = call.argument<String>("fileName")
                
                if (imageBytes != null && fileName != null) {
                    val path = saveImageToGallery(imageBytes, fileName)
                    if (path != null) {
                        result.success(path)
                    } else {
                        result.error("FAILED", "Failed to save image", null)
                    }
                } else {
                    result.error("INVALID_ARGUMENTS", "Missing arguments", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveImageToGallery(imageBytes: ByteArray, fileName: String): String? {
        try {
            val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
            
            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val contentResolver = applicationContext.contentResolver
            var uri: Uri? = null
            
            uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentResolver.insert(MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), contentValues)
            } else {
                contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            }

            if (uri != null) {
                contentResolver.openOutputStream(uri)?.use { outputStream ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                }
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    contentValues.clear()
                    contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, contentValues, null, null)
                }
                
                return getPathFromUri(applicationContext, uri)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun getPathFromUri(context: Context, uri: Uri): String? {
        val projection = arrayOf(MediaStore.Images.Media.DATA)
        val cursor = context.contentResolver.query(uri, projection, null, null, null)
        cursor?.use {
            if (it.moveToFirst()) {
                val columnIndex = it.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
                return it.getString(columnIndex)
            }
        }
        return uri.toString()
    }
}