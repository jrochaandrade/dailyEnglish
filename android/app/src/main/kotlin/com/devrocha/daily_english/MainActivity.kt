package com.devrocha.daily_english

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.devrocha.daily_english/files",
        ).setMethodCallHandler { call, result ->
            if (call.method != "openFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val filePath = call.argument<String>("path")
            val mimeType = call.argument<String>("mimeType") ?: "application/pdf"
            if (filePath.isNullOrBlank()) {
                result.error("invalid_path", "Arquivo inválido.", null)
                return@setMethodCallHandler
            }

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                File(filePath),
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            try {
                startActivity(intent)
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("viewer_unavailable", "Nenhum leitor disponível.", null)
            }
        }
    }
}
