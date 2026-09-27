package no.govia.mobile

import android.app.PictureInPictureParams
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val navigationChannel = "no.govia.mobile/navigation"
    private var navigationActive = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, navigationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setNavigationActive" -> {
                        navigationActive = call.argument<Boolean>("active") == true
                        updatePipParams()
                        result.success(null)
                    }
                    "enterPip" -> {
                        result.success(enterNavigationPip())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (navigationActive && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            enterNavigationPip()
        }
    }

    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(navigationActive)
        }
        setPictureInPictureParams(builder.build())
    }

    private fun enterNavigationPip(): Boolean {
        if (!navigationActive || Build.VERSION.SDK_INT < Build.VERSION_CODES.O || isInPictureInPictureMode) {
            return false
        }
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(9, 16))
            .build()
        return enterPictureInPictureMode(params)
    }
}
