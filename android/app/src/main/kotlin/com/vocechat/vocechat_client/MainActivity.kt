package com.vocechat.vocechat_client

import io.agora.agora_rtc_ng.AgoraPIPFlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AgoraPIPFlutterActivity() {
    private var updater: AndroidUpdateInstaller? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        updater = AndroidUpdateInstaller(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        updater?.dispose()
        updater = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
