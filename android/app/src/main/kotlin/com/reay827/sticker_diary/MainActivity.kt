package com.reay827.sticker_diary

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.gms.common.moduleinstall.ModuleInstall
import com.google.android.gms.common.moduleinstall.ModuleInstallRequest
import com.google.mlkit.vision.segmentation.subject.SubjectSegmentation
import com.google.mlkit.vision.segmentation.subject.SubjectSegmenterOptions
import android.util.Log

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "haru/subject_model")
            .setMethodCallHandler { call, result ->
                if (call.method != "ensureReady" && call.method != "isReady") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val segmenter = SubjectSegmentation.getClient(
                    SubjectSegmenterOptions.Builder().enableForegroundBitmap().build())
                val client = ModuleInstall.getClient(this)
                fun fail(error: Exception) {
                    Log.e("HaruSubjectModel", "Model preparation failed", error)
                    segmenter.close()
                    result.error("MODEL_DOWNLOAD_FAILED", error.message, null)
                }
                client.areModulesAvailable(segmenter)
                    .addOnSuccessListener { availability ->
                        if (availability.areModulesAvailable() || call.method == "isReady") {
                            segmenter.close()
                            result.success(availability.areModulesAvailable())
                        } else {
                            // The install task queues a download; it is NOT proof that
                            // the model is ready. Dart polls isReady before processing.
                            val request = ModuleInstallRequest.newBuilder().addApi(segmenter).build()
                            client.installModules(request)
                                .addOnSuccessListener { response ->
                                    segmenter.close()
                                    result.success(response.areModulesAlreadyInstalled())
                                }
                                .addOnFailureListener { fail(it) }
                        }
                    }
                    .addOnFailureListener { fail(it) }
            }
    }
}
