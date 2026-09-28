package com.sklive.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

object RoomBubbleChannel {
    const val OVERLAY_CHANNEL = "com.sklive.app/room_bubble"
    const val MAIN_CHANNEL = "com.sklive.app/room_bubble_main"

    const val EXTRA_BUBBLE_ACTION = "bubble_action"
    const val EXTRA_BUBBLE_ROOM_ID = "bubble_room_id"

    private const val PREFS = "sklive_room_bubble"
    private const val KEY_PENDING_ACTION = "pending_action"
    private const val KEY_PENDING_ROOM_ID = "pending_room_id"
    private const val KEY_LAST_ROOM_ID = "last_room_id"

    private val registeredEngines = mutableSetOf<Int>()
    @Volatile private var appContext: Context? = null
    @Volatile private var mainEngine: FlutterEngine? = null
    @Volatile private var lastRoomId: String = ""

    @JvmStatic
    fun init(context: Context) {
        appContext = context.applicationContext
        lastRoomId = prefs(context).getString(KEY_LAST_ROOM_ID, "") ?: ""
    }

    @JvmStatic
    fun register(activity: Activity, engine: FlutterEngine) {
        appContext = activity.applicationContext
        mainEngine = engine
        registerOnEngine(engine, isMain = true)
        // Redeliver any persisted action that survived a process restart.
        redeliverPersistedPending(engine)
    }

    /** Overlay isolate FlutterEngine — same channel so bubble tap can wake the app. */
    @JvmStatic
    fun registerOverlayEngine(context: Context, engine: FlutterEngine) {
        appContext = context.applicationContext
        registerOnEngine(engine, isMain = false)
    }

    private fun registerOnEngine(engine: FlutterEngine, isMain: Boolean) {
        val key = System.identityHashCode(engine)
        if (registeredEngines.contains(key)) return
        registeredEngines.add(key)

        MethodChannel(engine.dartExecutor.binaryMessenger, OVERLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringToForeground" -> {
                        val action = call.argument<String>("action") ?: ""
                        val roomId = call.argument<String>("roomId") ?: ""
                        if (roomId.isNotEmpty()) cacheRoomIdInternal(roomId)
                        // Persist close actions so Dart can recover if the
                        // 350ms one-shot delivery is lost.
                        if (action == "close_room" || action == "bubble_removed") {
                            persistPending(action, roomId)
                        }
                        launchMainActivity(action, roomId)
                        result.success(true)
                    }
                    "cacheRoomId" -> {
                        val roomId = call.argument<String>("roomId") ?: ""
                        if (roomId.isNotEmpty()) cacheRoomIdInternal(roomId)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        if (isMain) {
            MethodChannel(engine.dartExecutor.binaryMessenger, MAIN_CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "acknowledgePendingAction" -> {
                            clearPending()
                            result.success(true)
                        }
                        "consumePendingAction" -> {
                            val pending = readPending()
                            clearPending()
                            result.success(pending)
                        }
                        else -> result.notImplemented()
                    }
                }
        }
    }

    @JvmStatic
    fun launchMainActivity(action: String, roomId: String) {
        val ctx = appContext ?: return
        if (roomId.isNotEmpty()) cacheRoomIdInternal(roomId)
        val intent = Intent(ctx, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra(EXTRA_BUBBLE_ACTION, action)
            putExtra(EXTRA_BUBBLE_ROOM_ID, roomId)
        }
        ctx.startActivity(intent)
    }

    @JvmStatic
    fun deliverPendingAction(engine: FlutterEngine?, intent: Intent?) {
        val action = intent?.getStringExtra(EXTRA_BUBBLE_ACTION) ?: return
        val roomId = intent.getStringExtra(EXTRA_BUBBLE_ROOM_ID) ?: ""
        intent.removeExtra(EXTRA_BUBBLE_ACTION)
        intent.removeExtra(EXTRA_BUBBLE_ROOM_ID)

        if (action == "close_room" || action == "bubble_removed") {
            persistPending(action, roomId)
        }

        val target = engine ?: mainEngine ?: return
        Handler(Looper.getMainLooper()).postDelayed({
            invokeHandleBubbleAction(target, action, roomId)
        }, 350)
    }

    /**
     * Overlay service destroyed / task removed — ask Dart to hard-exit if the
     * hide was not an intentional resume close.
     *
     * Must be `@JvmStatic` so OverlayService reflection (`Class.getMethod`) works.
     */
    @JvmStatic
    fun notifyBubbleRemoved(reason: String = "service_removed") {
        val roomId = lastRoomId.ifEmpty {
            appContext?.let { prefs(it).getString(KEY_LAST_ROOM_ID, "") } ?: ""
        }
        persistPending("bubble_removed", roomId)

        val target = mainEngine
        if (target != null) {
            Handler(Looper.getMainLooper()).post {
                try {
                    invokeHandleBubbleAction(
                        target,
                        "bubble_removed",
                        roomId,
                        reason,
                    )
                } catch (_: Throwable) {
                    // Best-effort; process may already be dying.
                }
            }
            return
        }

        // App may be backgrounded without a live engine reference — wake it.
        if (roomId.isNotEmpty()) {
            launchMainActivity("bubble_removed", roomId)
        }
    }

    private fun invokeHandleBubbleAction(
        engine: FlutterEngine,
        action: String,
        roomId: String,
        reason: String? = null,
    ) {
        val payload = mutableMapOf<String, Any>(
            "action" to action,
            "roomId" to roomId,
        )
        if (reason != null) payload["reason"] = reason
        MethodChannel(
            engine.dartExecutor.binaryMessenger,
            MAIN_CHANNEL,
        ).invokeMethod("handleBubbleAction", payload)
    }

    private fun redeliverPersistedPending(engine: FlutterEngine) {
        Handler(Looper.getMainLooper()).postDelayed({
            val pending = readPending() ?: return@postDelayed
            val action = pending["action"] as? String ?: return@postDelayed
            val roomId = pending["roomId"] as? String ?: ""
            invokeHandleBubbleAction(engine, action, roomId)
        }, 500)
    }

    private fun cacheRoomIdInternal(roomId: String) {
        lastRoomId = roomId
        val ctx = appContext ?: return
        prefs(ctx).edit().putString(KEY_LAST_ROOM_ID, roomId).apply()
    }

    private fun persistPending(action: String, roomId: String) {
        val ctx = appContext ?: return
        prefs(ctx).edit()
            .putString(KEY_PENDING_ACTION, action)
            .putString(KEY_PENDING_ROOM_ID, roomId)
            .apply()
    }

    private fun clearPending() {
        val ctx = appContext ?: return
        prefs(ctx).edit()
            .remove(KEY_PENDING_ACTION)
            .remove(KEY_PENDING_ROOM_ID)
            .apply()
    }

    private fun readPending(): Map<String, Any>? {
        val ctx = appContext ?: return null
        val action = prefs(ctx).getString(KEY_PENDING_ACTION, null) ?: return null
        val roomId = prefs(ctx).getString(KEY_PENDING_ROOM_ID, "") ?: ""
        return mapOf("action" to action, "roomId" to roomId)
    }

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
