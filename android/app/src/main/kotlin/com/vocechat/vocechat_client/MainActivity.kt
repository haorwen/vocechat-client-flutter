package com.vocechat.vocechat_client

import io.agora.agora_rtc_ng.AgoraPIPFlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AgoraPIPFlutterActivity() {
    private var updater: AndroidUpdateInstaller? = null
    private var secureStorageCommit: SecureStorageCommit? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        secureStorageCommit = SecureStorageCommit(this, flutterEngine.dartExecutor.binaryMessenger)
        updater = AndroidUpdateInstaller(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        secureStorageCommit?.dispose()
        secureStorageCommit = null
        updater?.dispose()
        updater = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
