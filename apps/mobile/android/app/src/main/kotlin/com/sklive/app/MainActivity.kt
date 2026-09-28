package com.sklive.app

import com.sklive.app.youtube.RoomYoutubePlayerFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        RoomBubbleChannel.init(applicationContext)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "room-youtube-player",
            RoomYoutubePlayerFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        // Overlay isolate only — must not replace mainEngine or bubble_removed
        // delivery to the main Dart isolate will be lost.
        RoomBubbleChannel.register(this, flutterEngine)
        registerOverlayEngineBubbleChannel()
    }

    override fun onResume() {
        super.onResume()
        registerOverlayEngineBubbleChannel()
        RoomBubbleChannel.deliverPendingAction(flutterEngine, intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        RoomBubbleChannel.deliverPendingAction(flutterEngine, intent)
    }

    private fun registerOverlayEngineBubbleChannel() {
        FlutterEngineCache.getInstance()
            .get("myCachedEngine")
            ?.let { RoomBubbleChannel.registerOverlayEngine(applicationContext, it) }
    }
}
