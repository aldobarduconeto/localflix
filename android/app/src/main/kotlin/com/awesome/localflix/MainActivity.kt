package com.awesome.localflix

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pickerResult: MethodChannel.Result? = null
    private var documentsChannel: MethodChannel? = null
    // Durable handoff: Android can recreate the activity while DocumentsUI is open.
    private val pendingFolders get() = getSharedPreferences("folder_handoff", MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        documentsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "localflix/documents")
        documentsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "pendingFolders" -> result.success(
                    pendingFolders.getStringSet("uris", emptySet())!!.toList())
                "acknowledgeFolders" -> {
                    val acknowledged = (call.arguments as? List<*>)?.filterIsInstance<String>().orEmpty().toSet()
                    val remaining = pendingFolders.getStringSet("uris", emptySet())!!.toSet() - acknowledged
                    if (pendingFolders.edit().putStringSet("uris", remaining).commit()) result.success(null)
                    else result.error("save_failed", "Não foi possível confirmar as pastas salvas.", null)
                }
                "isTelevision" -> {
                    val mode = getSystemService(android.content.Context.UI_MODE_SERVICE) as android.app.UiModeManager
                    result.success(mode.currentModeType == android.content.res.Configuration.UI_MODE_TYPE_TELEVISION ||
                        packageManager.hasSystemFeature(android.content.pm.PackageManager.FEATURE_LEANBACK))
                }
                "pickFolder" -> {
                    if (pickerResult != null) {
                        result.error("picker_busy", "Uma seleção de pasta já está aberta.", null)
                    } else {
                        pickerResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
                            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION or
                                Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
                        try {
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, 7011)
                        } catch (e: Exception) {
                            pickerResult = null
                            result.error("picker_unavailable", "Não foi possível abrir o seletor de pastas.", null)
                        }
                    }
                }
                "scanFolders" -> {
                    val folders = call.arguments as? List<*> ?: emptyList<Any>()
                    io.execute {
                        try {
                            val scan = scanFolders(folders.filterIsInstance<String>())
                            main.post { if (!isDestroyed) result.success(scan) }
                        } catch (e: Exception) {
                            main.post { if (!isDestroyed) result.error("scan_failed", "Não foi possível ler as pastas autorizadas.", null) }
                        }
                    }
                }
                "readArtwork" -> {
                    val source = call.argument<String>("uri")
                    val width = call.argument<Int>("width")?.coerceIn(100, 1920) ?: 800
                    io.execute {
                        try {
                            val uri = Uri.parse(source ?: error("URI ausente"))
                            require(uri.scheme == "content")
                            // Downsample before passing bytes to Flutter; never load full-size
                            // camera images into the platform channel.
                            val bounds = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
                            contentResolver.openInputStream(uri)?.use { android.graphics.BitmapFactory.decodeStream(it, null, bounds) }
                            require(bounds.outWidth > 0 && bounds.outHeight > 0)
                            val options = android.graphics.BitmapFactory.Options().apply { inSampleSize = 1 }
                            while (maxOf(bounds.outWidth, bounds.outHeight) / options.inSampleSize.coerceAtLeast(1) > width * 2) {
                                options.inSampleSize = options.inSampleSize.coerceAtLeast(1) * 2
                            }
                            val bitmap = contentResolver.openInputStream(uri)?.use { android.graphics.BitmapFactory.decodeStream(it, null, options) }
                                ?: error("Imagem indisponível")
                            val bytes = try {
                                java.io.ByteArrayOutputStream().use { output ->
                                    bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, output)
                                    output.toByteArray()
                                }
                            } finally { bitmap.recycle() }
                            main.post { if (!isDestroyed) result.success(bytes) }
                        } catch (e: Exception) {
                            main.post { if (!isDestroyed) result.error("artwork_unavailable", "Capa local indisponível.", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Flutter activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7011) return
        val result = pickerResult
        pickerResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result?.success(null)
            return
        }
        try {
            val flags = (data?.flags ?: 0) and Intent.FLAG_GRANT_READ_URI_PERMISSION
            require(flags != 0)
            contentResolver.takePersistableUriPermission(uri, flags)
            val selected = pendingFolders.getStringSet("uris", emptySet())!!.toSet() + uri.toString()
            check(pendingFolders.edit().putStringSet("uris", selected).commit())
            result?.success(uri.toString())
        } catch (e: Exception) {
            result?.error("permission_denied", "Não foi possível manter o acesso. Escolha a pasta novamente e toque em Usar esta pasta.", null)
        }
    }

    private fun scanFolders(folders: List<String>): Map<String, Any> {
        val rows = linkedMapOf<String, Map<String, String>>()
        val migrations = linkedMapOf<String, String>()
        val warnings = mutableListOf<String>()
        val visited = mutableSetOf<String>()
        val extensions = setOf("mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "aiff", "wma",
            "mp4", "m4v", "mov", "mkv", "webm", "avi", "3gp", "mpeg", "mpg", "jpg", "jpeg", "png", "webp")
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE)
        for (source in folders.distinct()) {
            var tree = Uri.parse(source)
            if (tree.scheme != "content") {
                val recovered = contentResolver.persistedUriPermissions.firstOrNull {
                    it.isReadPermission && legacyPath(it.uri) == source.trimEnd('/')
                }?.uri
                if (recovered != null) {
                    tree = recovered
                    migrations[source] = recovered.toString()
                }
            }
            if (tree.scheme != "content" || !DocumentsContract.isTreeUri(tree)) {
                warnings.add("Autorize novamente a pasta $source: toque em Adicionar pasta e depois em Usar esta pasta.")
                continue
            }
            val granted = contentResolver.persistedUriPermissions.any { it.uri == tree && it.isReadPermission }
            if (!granted) {
                warnings.add("O acesso à pasta ${DocumentsContract.getTreeDocumentId(tree)} expirou. Selecione-a novamente.")
                continue
            }
            val queue = ArrayDeque<String>()
            queue.add(DocumentsContract.getTreeDocumentId(tree))
            while (queue.isNotEmpty() && !Thread.currentThread().isInterrupted) {
                val parent = queue.removeFirst()
                if (!visited.add("${tree.authority}:$parent")) continue
                try {
                    val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
                    val cursor = contentResolver.query(children, projection, null, null, null)
                        ?: error("Pasta indisponível")
                    cursor.use {
                        while (it.moveToNext()) {
                            val id = it.getString(0) ?: continue
                            val name = it.getString(1) ?: continue
                            if (it.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                                queue.add(id)
                            } else if (name.substringAfterLast('.', "").lowercase(java.util.Locale.ROOT) in extensions) {
                                val identity = "${tree.authority}:$id"
                                rows.putIfAbsent(identity, mapOf(
                                    "uri" to DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                                    "name" to name,
                                    "parent" to "${tree.authority}:$parent"))
                            }
                        }
                    }
                } catch (e: Exception) {
                    warnings.add("Não foi possível ler $parent. Verifique a autorização da pasta e tente novamente.")
                }
            }
        }
        return mapOf("files" to rows.values.toList(), "warnings" to warnings.distinct(), "migrations" to migrations)
    }

    private fun legacyPath(uri: Uri): String? {
        if (uri.authority != "com.android.externalstorage.documents" || !DocumentsContract.isTreeUri(uri)) return null
        val id = DocumentsContract.getTreeDocumentId(uri)
        val colon = id.indexOf(':')
        if (colon < 0) return null
        val volume = id.substring(0, colon)
        val relative = id.substring(colon + 1).trimEnd('/')
        val root = if (volume == "primary") "/storage/emulated/0" else "/storage/$volume"
        return if (relative.isEmpty()) root else "$root/$relative"
    }

    override fun onDestroy() {
        documentsChannel?.setMethodCallHandler(null)
        pickerResult?.error("activity_closed", "Seleção de pasta interrompida.", null)
        pickerResult = null
        io.shutdownNow()
        super.onDestroy()
    }
}
