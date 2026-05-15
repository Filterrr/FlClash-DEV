package com.follow.clask


import com.follow.clask.plugins.AppPlugin
import com.follow.clask.plugins.ServicePlugin
import com.follow.clask.plugins.TilePlugin
import com.follow.clask.plugins.VpnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(AppPlugin())
        flutterEngine.plugins.add(VpnPlugin())
        flutterEngine.plugins.add(ServicePlugin())
        flutterEngine.plugins.add(TilePlugin())
        GlobalState.flutterEngine = flutterEngine
    }

    override fun onDestroy() {
        GlobalState.flutterEngine = null
        super.onDestroy()
    }
}