package com.polarisfinance.polaris_finance

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "polaris_finance/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("invalid_path", "Falta la ruta del APK", null)
                    } else {
                        try {
                            result.success(installApk(path))
                        } catch (error: Exception) {
                            result.error("install_failed", error.message, null)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    /** Abre el instalador de paquetes del sistema con el APK descargado. */
    private fun installApk(path: String): Boolean {
        val file = File(path)
        if (!file.exists()) return false

        val authority = "$packageName.fileprovider"
        val uri: Uri = FileProvider.getUriForFile(this, authority, file)

        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, "application/vnd.android.package-archive")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        return true
    }
}
