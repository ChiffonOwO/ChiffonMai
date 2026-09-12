package com.example.my_first_flutter_app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.view.Display
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/media_store"

    /** 收藏夹「一键导入」通道：把文件管理器/分享进来的文件路径交给 Dart。 */
    private val IMPORT_CHANNEL = "com.example.app/open_file"

    /**
     * 屏幕刷新率通道。
     *
     * Flutter 引擎从不调用 Android 的 `Surface.setFrameRate()`（见 flutter/flutter#160952），
     * 所以系统默认按 60Hz 合成，只在触摸后短暂升到 120Hz 再掉回去。
     * 谱面播放页必须自己投票要高刷，否则就会一直卡在「几秒 120 → 掉 60」的循环里。
     */
    private val DISPLAY_CHANNEL = "com.example.app/display"

    private var importChannel: MethodChannel? = null

    /** 进入播放页前的窗口 displayModeId，退出时原样还回去。 */
    private var savedDisplayModeId: Int? = null
    private var savedRefreshRate: Float? = null
    private var highRefreshActive = false

    /**
     * 待交给 Dart 处理的导入文件路径。
     *
     * 冷启动时 `configureFlutterEngine` 会先把路径存这里，等 Dart 侧注册好监听后
     * 主动调 `getInitialImportPath` 取走——直接 invokeMethod 会撞上「Dart 还没
     * 注册 handler」的竞态，消息就丢了。
     */
    private var pendingImportPath: String? = null

    /**
     * Dart 侧是否已经注册好导入监听。
     *
     * 由 Dart 启动后第一次调 `getInitialImportPath` 置位。只有它为 true 时，
     * 实时投递（`onFileOpened`）才是可靠的；否则必须留在 [pendingImportPath] 里等 Dart 来取。
     */
    private var dartImportReady = false

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

        importChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, IMPORT_CHANNEL)
        importChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart 启动后主动取走冷启动带来的文件；取一次即清空，避免重启后重复导入
                "getInitialImportPath" -> {
                    dartImportReady = true
                    val path = pendingImportPath
                    pendingImportPath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }

        // 冷启动：Activity 的启动 intent 就带着文件
        handleImportIntent(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setHighRefreshRate" -> result.success(setHighRefreshRate())
                "restoreRefreshRate" -> {
                    restoreRefreshRate()
                    result.success(null)
                }
                "queryRefreshRate" -> result.success(queryRefreshRateInfo())
                else -> result.notImplemented()
            }
        }
    }

    // ---------------------------------------------------------------------
    // 高刷新率
    // ---------------------------------------------------------------------

    /** 让窗口按屏幕支持的最高刷新率合成，返回实际生效的信息。 */
    private fun setHighRefreshRate(): Map<String, Any?> {
        val info = mutableMapOf<String, Any?>()
        try {
            val display = currentDisplay()
            if (display == null) {
                info["ok"] = false
                info["error"] = "no display"
                return info
            }

            val lp = window.attributes
            val rates = display.supportedModes
                ?.map { it.refreshRate }
                ?.distinct()
                ?.sorted()
                ?: emptyList()
            info["supportedRates"] = rates

            val currentId = display.mode?.modeId ?: 0

            // 只在第一次进入时保存原始设置，避免重复调用把「已经是高刷」的状态存成基线
            if (!highRefreshActive) {
                savedDisplayModeId = lp.preferredDisplayModeId
                savedRefreshRate = lp.preferredRefreshRate
            }

            // 目标刷新率必须取自**实际选中的 mode**，不能用全局最高值：
            // 分辨率一致性约束可能让 120Hz 的 mode 落选，此时却说 FIXED_SOURCE 120，
            // 就会和真实 mode 对不上。
            val bestMode = bestHighRefreshMode(display)
            val targetRate = bestMode?.refreshRate ?: display.refreshRate

            // preferredDisplayModeId 是 API 23+ 的窗口属性，会一直生效到窗口销毁，
            // 比给 Surface 投票更稳，是这里的主力手段。
            if (bestMode != null && bestMode.modeId != 0) {
                lp.preferredDisplayModeId = bestMode.modeId
                info["modeId"] = bestMode.modeId
                info["modeRate"] = targetRate
                info["modeResolution"] = "${bestMode.physicalWidth}x${bestMode.physicalHeight}"
            }
            // preferredRefreshRate 作为附加提示一起给上；两者一致时不会被系统当成冲突
            lp.preferredRefreshRate = targetRate
            window.attributes = lp
            info["appliedRate"] = targetRate
            info["currentModeId"] = currentId
            info["currentRate"] = display.refreshRate
            highRefreshActive = true

            // API 30+ 再直接给 Surface 投一票（SurfaceFlinger 的官方入口），双保险
            applySurfaceFrameRate(targetRate)
            info["ok"] = true
        } catch (e: Exception) {
            info["ok"] = false
            info["error"] = e.message
        }
        return info
    }

    /** 退出播放页：把刷新率交还给系统。 */
    private fun restoreRefreshRate() {
        try {
            if (!highRefreshActive) return
            val lp = window.attributes
            lp.preferredDisplayModeId = savedDisplayModeId ?: 0
            lp.preferredRefreshRate = savedRefreshRate ?: 0f
            window.attributes = lp
            // rate 传 0 表示清除本 Surface 的刷新率偏好
            applySurfaceFrameRate(0f)
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            highRefreshActive = false
            savedDisplayModeId = null
            savedRefreshRate = null
        }
    }

    private fun queryRefreshRateInfo(): Map<String, Any?> {
        val info = mutableMapOf<String, Any?>()
        try {
            val display = currentDisplay()
            info["supportedRates"] = display?.supportedModes
                ?.map { it.refreshRate }
                ?.distinct()
                ?.sorted()
            info["currentRate"] = display?.refreshRate
            info["currentModeId"] = display?.mode?.modeId
            info["apiLevel"] = Build.VERSION.SDK_INT
            info["active"] = highRefreshActive
        } catch (e: Exception) {
            info["error"] = e.message
        }
        return info
    }

    private fun currentDisplay(): Display? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * 挑一个高刷的 display mode。
     *
     * 优先在「分辨率与当前一致」的模式里挑，避免为了刷高率把分辨率也一起换掉
     * （部分设备的高刷模式挂在不同的分辨率上）。
     *
     * 返回整个 Mode 而不只是 modeId：后面设 preferredRefreshRate 和给 Surface
     * 投票时都必须用**这个 mode 的**刷新率，用全局最高值会和实际选中的 mode 对不上。
     */
    private fun bestHighRefreshMode(display: Display): Display.Mode? {
        val modes = display.supportedModes ?: return null
        if (modes.isEmpty()) return null

        val current = display.mode
        val sameResolution = modes.filter {
            it.physicalWidth == current.physicalWidth &&
                it.physicalHeight == current.physicalHeight
        }
        val pool = if (sameResolution.isNotEmpty()) sameResolution else modes.toList()
        return pool.maxByOrNull { it.refreshRate }
    }

    /** API 30+ 直接给 Flutter 的 Surface 设置刷新率；rate <= 0 表示清除偏好。 */
    private fun applySurfaceFrameRate(rate: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            val surface = findSurfaceView()?.holder?.surface ?: return
            if (!surface.isValid) return
            if (rate <= 0f) {
                surface.setFrameRate(
                    0f,
                    Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                    Surface.CHANGE_FRAME_RATE_ALWAYS
                )
            } else {
                surface.setFrameRate(
                    rate,
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                    Surface.CHANGE_FRAME_RATE_ALWAYS
                )
            }
        } catch (e: Exception) {
            // 拿不到 Surface（比如正处于 hybrid composition 切换中）不影响窗口属性那条路
            e.printStackTrace()
        }
    }

    /** 在视图树里找承载 Flutter 渲染的 SurfaceView。 */
    private fun findSurfaceView(): SurfaceView? {
        val root = window.decorView as? ViewGroup ?: return null
        val queue = ArrayDeque<View>()
        queue.addLast(root)
        while (queue.isNotEmpty()) {
            val view = queue.removeFirst()
            if (view is SurfaceView && view.holder.surface.isValid) return view
            if (view is ViewGroup) {
                for (i in 0 until view.childCount) {
                    queue.addLast(view.getChildAt(i))
                }
            }
        }
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // 热启动：App 已在后台，用户又点开一个文件
        handleImportIntent(intent)
    }

    /** 从 VIEW / SEND intent 里取出文件并转交给 Dart。 */
    private fun handleImportIntent(intent: Intent?) {
        if (intent == null) return

        // 声明为不可空 Uri：`?: return` 已经把空分支挡掉了，
        // 若写成 Uri? 会保留可空类型，后面传给 copyToCache 时无法通过编译
        val uri: Uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> extractSendStream(intent)
            else -> null
        } ?: return

        // 消费掉这个 intent。Activity 因进程被回收后重建时，系统会把 getIntent()
        // 原样重放一遍，不清掉的话同一个文件会被反复弹导入框。
        intent.action = null
        intent.data = null
        intent.removeExtra(Intent.EXTRA_STREAM)

        val localPath = copyToCache(uri) ?: return

        pendingImportPath = localPath

        // 只有 Dart 已经注册好监听时才实时投递；投递成功就把 pending 清掉，
        // 否则下次引擎重启会把这个旧文件当成「启动时带来的文件」再导一次。
        // Dart 还没就绪时保留 pending，由它的 getInitialImportPath 取走。
        if (dartImportReady) {
            importChannel?.invokeMethod("onFileOpened", localPath)
            pendingImportPath = null
        }
    }

    @Suppress("DEPRECATION")
    private fun extractSendStream(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }
    }

    /**
     * 把 content:// 指向的文件复制进应用缓存目录。
     *
     * Dart 的 `File(path)` 只认真实文件系统路径，而文件管理器和分享传进来的
     * 多半是 content:// URI，必须先落盘成普通文件。
     */
    private fun copyToCache(uri: Uri): String? {
        return try {
            val displayName = queryDisplayName(uri) ?: "import_${System.currentTimeMillis()}"
            val safeName = displayName.replace(Regex("[\\\\/:*?\"<>|]"), "_")
            val dir = File(cacheDir, "incoming_imports")
            if (!dir.exists()) dir.mkdirs()

            // 每次导入都会落一个新文件（文件名带时间戳），顺手清掉超过一天的旧副本，
            // 否则这个目录只增不减。留一天是为了不误删正在被 Dart 侧读取的文件。
            purgeOldImports(dir)

            // 前缀时间戳，避免同名文件互相覆盖
            val target = File(dir, "${System.currentTimeMillis()}_$safeName")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null

            target.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun purgeOldImports(dir: File) {
        try {
            val cutoff = System.currentTimeMillis() - 24L * 60 * 60 * 1000
            dir.listFiles()?.forEach { file ->
                if (file.isFile && file.lastModified() < cutoff) file.delete()
            }
        } catch (_: Exception) {
            // 清理失败不影响导入本身
        }
    }

    /** 读取 content:// URI 的显示名（含后缀）。 */
    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null, null, null
            )
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } catch (e: Exception) {
            null
        } finally {
            cursor?.close()
        }
    }

    private fun saveImageToGallery(imageBytes: ByteArray, fileName: String): String? {
        try {
            // 根据文件扩展名判断 MIME 类型
            val mimeType = when {
                fileName.lowercase().endsWith(".jpg") || fileName.lowercase().endsWith(".jpeg") -> "image/jpeg"
                else -> "image/png"
            }

            val contentValues = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
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
                // 直接写入原始字节，不重新编码，保留 Dart 侧的 JPEG/PNG 编码结果
                contentResolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(imageBytes)
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
