package com.sklive.app.youtube

import android.content.Context
import android.content.ContextWrapper
import android.view.View
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.PlayerConstants
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.YouTubePlayer
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.listeners.AbstractYouTubePlayerListener
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.options.IFramePlayerOptions
import com.pierfrancescosoffritti.androidyoutubeplayer.core.player.views.YouTubePlayerView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class RoomYoutubePlayerView(
    context: Context,
    viewId: Int,
    creationParams: Map<String, Any>?,
    messenger: BinaryMessenger,
) : PlatformView {

    private val playerView = YouTubePlayerView(context).apply {
        enableAutomaticInitialization = false
    }

    private var youTubePlayer: YouTubePlayer? = null

    @Volatile
    private var currentTimeSeconds = 0.0

    @Volatile
    private var isPlayingState = false

    private val channel = MethodChannel(messenger, "com.ravestar.app/room_youtube_$viewId")

    init {
        findFlutterActivity(context)?.lifecycle?.addObserver(playerView)

        val showControls = creationParams?.get("showControls") as? Boolean ?: false
        val options = IFramePlayerOptions.Builder(context)
            .controls(if (showControls) 1 else 0)
            .fullscreen(0)
            .rel(0)
            .ivLoadPolicy(3)
            .ccLoadPolicy(0)
            .build()

        playerView.initialize(
            object : AbstractYouTubePlayerListener() {
                override fun onReady(player: YouTubePlayer) {
                    youTubePlayer = player
                    val videoId = creationParams?.get("videoId") as? String ?: return
                    val startAt = (creationParams["startAt"] as? Number)?.toFloat() ?: 0f
                    val autoPlay = creationParams["autoPlay"] as? Boolean ?: true
                    if (autoPlay) {
                        player.loadVideo(videoId, startAt)
                    } else {
                        player.cueVideo(videoId, startAt)
                    }
                }

                override fun onCurrentSecond(player: YouTubePlayer, second: Float) {
                    currentTimeSeconds = second.toDouble()
                }

                override fun onStateChange(
                    player: YouTubePlayer,
                    state: PlayerConstants.PlayerState,
                ) {
                    isPlayingState = state == PlayerConstants.PlayerState.PLAYING
                }
            },
            true,
            options,
        )

        channel.setMethodCallHandler { call, result ->
            val player = youTubePlayer
            when (call.method) {
                "play" -> {
                    player?.play()
                    result.success(null)
                }
                "pause" -> {
                    player?.pause()
                    result.success(null)
                }
                "seekTo" -> {
                    val seconds = call.argument<Double>("seconds")?.toFloat() ?: 0f
                    player?.seekTo(seconds)
                    result.success(null)
                }
                "loadVideo" -> {
                    val videoId = call.argument<String>("videoId") ?: ""
                    val startAt = call.argument<Double>("startAt")?.toFloat() ?: 0f
                    player?.loadVideo(videoId, startAt)
                    result.success(null)
                }
                "getCurrentTime" -> result.success(currentTimeSeconds)
                "isPlaying" -> result.success(isPlayingState)
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = playerView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        playerView.release()
    }

    private fun findFlutterActivity(context: Context): FlutterActivity? {
        var ctx: Context? = context
        while (ctx != null) {
            if (ctx is FlutterActivity) return ctx
            ctx = if (ctx is ContextWrapper) ctx.baseContext else null
        }
        return null
    }
}
