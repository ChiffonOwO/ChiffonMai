package com.example.my_first_flutter_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.TypedValue
import android.widget.RemoteViews
import java.io.File

/**
 * 随身听的自定义通知栏播放器。
 *
 * ## 为什么自己写而不用 audio_service 的通知
 *
 * 需求要的布局是「曲绘占左侧整高，右侧三行 = 曲名 / 艺术家 / 播放控制」。
 * audio_service（以及它底层的 `NotificationCompat.MediaStyle`）**只暴露
 * 标题/副标题/副文本/大图标与按钮列表，布局由系统决定**，做不到这个排版。
 * 所以这里用 `RemoteViews` 自绘一条通知。
 *
 * ## 怎么做到「只有一条通知」
 *
 * 关键：**用和 audio_service 相同的通知 ID**（[NOTIFICATION_ID] = 1124）。
 * 同 ID 的通知互相替换，所以 `notify(1124, 我们的通知)` 会把 audio_service 那条
 * 顶掉，最终只看得到我们要的布局。
 *
 * 已核实的前提（都在 audio_service 0.18.19 源码里确认过）：
 *   1. `AudioService.NOTIFICATION_ID = 1124`，写死的；
 *   2. 它调 `notificationManager.cancel(1124)` **只发生在 `deactivateMediaSession()`**
 *      —— 即服务销毁时。正常播放/暂停期间不会 cancel，我们顶掉的通知不会被它清掉；
 *   3. 它暂停时用 `STOP_FOREGROUND_DETACH`（**保留**通知），所以暂停后我们的通知
 *      也不会跟着消失。
 *
 * ⚠️ 但**光是同 ID 还不够**：`AudioService.setState()` 在「开始播放」时会走
 *    `enterPlayingState() → internalStartForeground() → startForeground(1124, 默认布局)`
 *    （audio_service 0.18.19 的 AudioService.java 559-563 / 705-728 行）。
 *    这一次 post 必然落在我们 push 之后几十毫秒，于是**播放中显示的是系统默认样式，
 *    手动暂停一下才变回我们的布局**（暂停只 `stopForeground(DETACH)`，不重建通知）。
 *    对策见 [scheduleReassert]：收到 update 后用几个错开的延时再 post 几次，把它顶回来。
 *
 * ## 职责划分
 *
 * 这个服务**只负责显示与把点击回传**，不碰播放：
 *   * 曲绘：由 Dart 侧把本地文件绝对路径传进来（Dart 已经把它下载进
 *     `DefaultCacheManager` 了），Kotlin 只 `BitmapFactory.decodeFile`。
 *     这样 Kotlin 侧不需要任何网络代码，也不会有线程问题。
 *   * 点击：`prev/next/play` 三个按钮通过 [PortableNotificationBridge] 回传 Dart，
 *     由 `PortablePlayerController` 执行 —— 保证「点通知栏」和「点 App 内按钮」
 *     走的是同一条代码路径，不会出现状态不一致。
 *   * 锁屏/耳机按键：由 audio_service 的 MediaSession 负责（我们没有动它）。
 */
class PortableNotificationService : Service() {

    companion object {
        /**
         * 与 `com.ryanheise.audioservice.AudioService.NOTIFICATION_ID` 一致。
         * **改这个值会让通知变成两条**（audio_service 那条不再被顶掉）。
         */
        const val NOTIFICATION_ID = 1124

        const val CHANNEL_ID = "com.example.my_first_flutter_app.channel.portable_custom"

        const val ACTION_UPDATE = "com.example.my_first_flutter_app.PORTABLE_UPDATE"
        const val ACTION_HIDE = "com.example.my_first_flutter_app.PORTABLE_HIDE"
        const val ACTION_MEDIA = "com.example.my_first_flutter_app.PORTABLE_MEDIA_ACTION"

        const val EXTRA_MEDIA_ACTION = "mediaAction"

        /**
         * 布局里 portable_art 的边长（dp）。改 R.layout.portable_notification 要同步改这里
         * —— Kotlin 侧按它把曲绘裁成圆角方块。
         */
        private const val ART_SIZE_DP = 56f

        /**
         * 曲绘圆角半径占边长的比例（56dp × 0.25 = 14dp）。
         * RemoteViews 里的 ImageView 不支持 clipToOutline / ShapeableImageView，
         * 圆角只能在这里裁，见 [roundToSquare]。
         */
        private const val ART_CORNER_RATIO = 0.25f

        /**
         * 「重申」通知的延时表（ms，相对收到 update 的时刻）。
         *
         * 起因见 [scheduleReassert]：播放开始时 audio_service 会用同一个 ID 再 post
         * 一条默认通知，把我们这份顶掉；它那一下必然在我们 push 之后几十毫秒内，
         * 所以这里错开几个时间点把我们的布局顶回来。
         */
        private val REASSERT_DELAYS = longArrayOf(260L, 700L, 1600L)

        fun update(context: Context, state: PortableNotificationState) {
            val intent = Intent(context, PortableNotificationService::class.java).apply {
                action = ACTION_UPDATE
                state.writeTo(this)
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                // 极少数情况下（后台被限制）起不来 —— 通知栏不可用，但不影响播放
                android.util.Log.w("PortableNotif", "更新通知失败: $e")
            }
        }

        fun hide(context: Context) {
            try {
                context.startService(
                    Intent(context, PortableNotificationService::class.java).apply {
                        action = ACTION_HIDE
                    }
                )
            } catch (_: Exception) {
                // 服务本来就没在跑，忽略
            }
        }
    }

    private var isForeground = false
    private var state: PortableNotificationState? = null

    /** 曲绘缓存：同一路径不重复读盘。 */
    private var cachedArtPath: String? = null
    private var cachedArt: Bitmap? = null

    private lateinit var notificationManager: NotificationManager

    /** 「重申」通知用（见 [scheduleReassert]）。Service 的回调都在主线程，这里同样。 */
    private val reassertHandler = Handler(Looper.getMainLooper())
    private var reassertIndex = 0
    private val reassertRunnable = Runnable { reassertNotification() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY
        when (intent.action) {
            ACTION_HIDE -> {
                stopPlaybackNotification()
                return START_NOT_STICKY
            }
            ACTION_MEDIA -> {
                val action = intent.getStringExtra(EXTRA_MEDIA_ACTION)
                if (action != null) PortableNotificationBridge.dispatch(action)
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                state = PortableNotificationState.from(intent)
                showOrUpdate()
            }
        }
        return START_NOT_STICKY
    }

    // ── 通知 ────────────────────────────────────────────────────────────────

    private fun showOrUpdate() {
        val current = state ?: return
        val notification = buildNotification(current)
        try {
            if (!isForeground) {
                startForeground(NOTIFICATION_ID, notification)
                isForeground = true
            } else {
                notificationManager.notify(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            // Android 12+ 在后台不允许启动前台服务，或通知权限被拒 —— 记录但不崩
            android.util.Log.w("PortableNotif", "显示通知失败: $e")
            return
        }
        scheduleReassert()
    }

    /**
     * 排一串「重申」：过一小会儿再用**同一个 ID** post 一次同一份内容。
     *
     * ## 为什么需要它
     *
     * 「播放中显示系统默认样式，暂停后才变自定义样式」的原因**不是**我们没推送，
     * 而是播放状态翻转时 audio_service 会抢在我们后面 post 一条默认 MediaStyle 的
     * 通知（同 ID 1124）：
     *
     *   Dart `play()` → 原生 `setState(playing=true)` → `enterPlayingState()`
     *                 → `internalStartForeground()` → `startForeground(1124, 默认)`
     *
     * 它是一次**并发**的写入，谁后写谁生效，纯靠 Dart 侧的时机赢不了（Dart 推
     * 通知要绕 MainActivity + startForegroundService，音频状态那次是直连）。
     * 暂停时它只用 `stopForeground(DETACH)`、不重建通知，所以那一侧反而是我们稳定赢
     * ——「暂停后才好看」的现象就是这么来的。
     *
     * 这里不等运气：每次收到 update 都按 [REASSERT_DELAYS] 错开再写几次。
     * 每一次写法与内容完全一致（`setOnlyAlertOnce`），不会闪、不会响。
     */
    private fun scheduleReassert() {
        reassertHandler.removeCallbacks(reassertRunnable)
        reassertIndex = 0
        reassertHandler.postDelayed(reassertRunnable, REASSERT_DELAYS[0])
    }

    private fun reassertNotification() {
        val current = state
        if (current != null && isForeground) {
            try {
                notificationManager.notify(NOTIFICATION_ID, buildNotification(current))
            } catch (_: Exception) {
                // 通知权限被撤 / 后台被限制 —— 忽略，下一次 push 还会来
            }
        }
        reassertIndex++
        if (reassertIndex < REASSERT_DELAYS.size) {
            val gap = REASSERT_DELAYS[reassertIndex] - REASSERT_DELAYS[reassertIndex - 1]
            reassertHandler.postDelayed(reassertRunnable, gap)
        }
    }

    private fun stopPlaybackNotification() {
        // 别让排着的「重申」在隐藏之后又把通知贴回来
        reassertHandler.removeCallbacks(reassertRunnable)
        try {
            if (isForeground) {
                stopForeground(STOP_FOREGROUND_REMOVE)
                isForeground = false
            }
            notificationManager.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {
            // 忽略
        }
        cachedArtPath = null
        cachedArt = null
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (notificationManager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "随身听播放",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "显示正在播放的曲目与播放控制"
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun buildNotification(current: PortableNotificationState): Notification {
        val views = RemoteViews(packageName, R.layout.portable_notification)
        views.setTextViewText(
            R.id.portable_title,
            current.title.ifEmpty { "随身听" }
        )
        views.setTextViewText(
            R.id.portable_artist,
            current.artist.ifEmpty { "未知艺术家" }
        )
        views.setImageViewResource(
            R.id.portable_play,
            if (current.isPlaying) R.drawable.portable_ic_pause
            else R.drawable.portable_ic_play
        )
        // 到头 / 到尾时按钮仍然占位（布局不跳），但淡一档：表示「点了也没用」
        views.setImageViewResource(
            R.id.portable_prev,
            if (current.hasPrevious) R.drawable.portable_ic_prev
            else R.drawable.portable_ic_prev_dim
        )
        views.setImageViewResource(
            R.id.portable_next,
            if (current.hasNext) R.drawable.portable_ic_next
            else R.drawable.portable_ic_next_dim
        )

        val art = resolveArt(current.artPath)
        if (art != null) {
            views.setImageViewBitmap(R.id.portable_art, art)
        } else {
            // 没有曲绘时退回应用图标，避免左侧留一个空洞
            views.setImageViewResource(R.id.portable_art, R.mipmap.ic_launcher)
        }

        views.setOnClickPendingIntent(
            R.id.portable_prev,
            mediaAction("previous", current.hasPrevious)
        )
        views.setOnClickPendingIntent(
            R.id.portable_play,
            mediaAction("toggle", true)
        )
        views.setOnClickPendingIntent(
            R.id.portable_next,
            mediaAction("next", current.hasNext)
        )
        views.setOnClickPendingIntent(R.id.portable_root, openAppIntent())

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(views)
            // 展开态复用同一套布局：系统会把它拉宽，右侧留白随之消失
            .setCustomBigContentView(views)
            .setContentIntent(openAppIntent())
            .setOngoing(current.isPlaying)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            // 通知的强调色：系统拿它给「应用名 / 小图标」上色，取主题 seed
            .setColor(color(R.color.portable_accent))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setStyle(Notification.MediaStyle())
        }
        return builder.build()
    }

    private fun resolveArt(path: String?): Bitmap? {
        if (path.isNullOrEmpty()) return null
        if (path == cachedArtPath) return cachedArt
        val decoded = try {
            val file = File(path)
            if (file.exists()) BitmapFactory.decodeFile(path) else null
        } catch (_: Exception) {
            null
        }
        // 缓存存**裁好的**那张，不是解码结果：否则每次 push（含重申）都要重裁一遍
        cachedArtPath = path
        cachedArt = decoded?.let { roundToSquare(it, path) }
        return cachedArt
    }

    /**
     * 把曲绘裁成圆角方块：边长 = [ART_SIZE_DP] 对应的像素，圆角 = 边长 × [ART_CORNER_RATIO]。
     *
     * 为什么非要在 Kotlin 这一侧做：RemoteViews 里的 ImageView 用不了
     * `clipToOutline`、也没有 ShapeableImageView，给 ImageView 套个圆角背景也**盖不住**
     * 方角位图 —— 照原样贴图，通知栏里就是方角曲绘。
     *
     * 顺带做两件事：centerCrop（曲绘不一定是 1:1）、把尺寸压到 56dp 对应的像素
     * （位图要过 Binder，越大越容易撞上限）。
     */
    private fun roundToSquare(src: Bitmap, cacheKey: String): Bitmap = try {
        val size = TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            ART_SIZE_DP,
            resources.displayMetrics
        ).toInt()
        if (size <= 0 || src.width <= 0 || src.height <= 0) {
            src
        } else {
            val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            val matrix = Matrix()
            val scale = maxOf(size / src.width.toFloat(), size / src.height.toFloat())
            matrix.setScale(scale, scale)
            matrix.postTranslate(
                (size - src.width * scale) / 2f,
                (size - src.height * scale) / 2f
            )
            paint.shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
                .also { it.setLocalMatrix(matrix) }
            val radius = size * ART_CORNER_RATIO
            canvas.drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), radius, radius, paint)
            output
        }
    } catch (e: Exception) {
        // 裁失败（极端 OOM 等）就用原图：宁可方角，也别让通知栏空一块
        android.util.Log.w("PortableNotif", "曲绘 $cacheKey 裁圆角失败: $e")
        src
    }

    // ── 点击事件 ────────────────────────────────────────────────────────────

    private fun mediaAction(action: String, enabled: Boolean): PendingIntent? {
        if (!enabled) return null
        val intent = Intent(this, PortableNotificationService::class.java).apply {
            this.action = ACTION_MEDIA
            putExtra(EXTRA_MEDIA_ACTION, action)
        }
        // requestCode 用 action 的 hash 区分，避免三个按钮共用同一个 PendingIntent
        return PendingIntent.getService(
            this,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** 取颜色资源：API 23 前后的写法不同，收口一处。 */
    private fun color(id: Int): Int = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        getColor(id)
    } else {
        @Suppress("DEPRECATION")
        resources.getColor(id)
    }

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onDestroy() {
        reassertHandler.removeCallbacks(reassertRunnable)
        isForeground = false
        super.onDestroy()
    }
}

/** 通知栏要显示的内容。用 Intent extra 在 MainActivity → Service 之间传递。 */
data class PortableNotificationState(
    val title: String,
    val artist: String,
    val artPath: String?,
    val isPlaying: Boolean,
    val hasNext: Boolean,
    val hasPrevious: Boolean
) {
    fun writeTo(intent: Intent) {
        intent.putExtra("title", title)
        intent.putExtra("artist", artist)
        intent.putExtra("artPath", artPath)
        intent.putExtra("isPlaying", isPlaying)
        intent.putExtra("hasNext", hasNext)
        intent.putExtra("hasPrevious", hasPrevious)
    }

    companion object {
        fun from(intent: Intent) = PortableNotificationState(
            title = intent.getStringExtra("title") ?: "",
            artist = intent.getStringExtra("artist") ?: "",
            artPath = intent.getStringExtra("artPath"),
            isPlaying = intent.getBooleanExtra("isPlaying", false),
            hasNext = intent.getBooleanExtra("hasNext", false),
            hasPrevious = intent.getBooleanExtra("hasPrevious", false)
        )
    }
}

/**
 * Dart ↔ 通知栏点击的桥。
 *
 * `MainActivity` 在建立 MethodChannel 时注册 [dispatch] 的实现；通知栏按钮被点时
 * 由 [PortableNotificationService] 调用 [dispatch]，事件就流回 Dart。
 */
object PortableNotificationBridge {
    @Volatile
    var dispatch: (String) -> Unit = {}
}
