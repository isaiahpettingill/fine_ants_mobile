package com.example.fine_ants_mobile

import android.content.ContentResolver
import android.net.Uri
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "fine_ants_mobile/saf"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "persistUriPermission" -> {
                        val treeUri = call.argument<String>("treeUri")
                        if (treeUri == null) {
                            result.error("ARG", "treeUri is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val uri = Uri.parse(treeUri)
                            val flags = (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                            contentResolver.takePersistableUriPermission(uri, flags)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("PERSIST", e.message, null)
                        }
                    }
                    "writeFileToTree" -> {
                        val treeUri = call.argument<String>("treeUri")
                        val displayName = call.argument<String>("displayName")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (treeUri == null || displayName == null || bytes == null) {
                            result.error("ARG", "treeUri, displayName, bytes are required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val output = createDocumentAndOpenOutputStream(contentResolver, Uri.parse(treeUri), mimeType, displayName)
                            output.use { it.write(bytes) }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("WRITE", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun createDocumentAndOpenOutputStream(
        resolver: ContentResolver,
        treeUri: Uri,
        mimeType: String,
        displayName: String
    ) = run {
        val docId = DocumentsContract.getTreeDocumentId(treeUri)
        val parentDocUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
        val child = DocumentsContract.createDocument(resolver, parentDocUri, mimeType, displayName)
            ?: throw IllegalStateException("Failed to create document")
        resolver.openOutputStream(child, "w") ?: throw IllegalStateException("Failed to open output stream")
    }
}
