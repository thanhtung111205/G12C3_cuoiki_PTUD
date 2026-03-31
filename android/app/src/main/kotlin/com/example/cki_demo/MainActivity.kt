package com.example.cki_demo

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val hapticsChannelName = "cki_demo/haptics"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, hapticsChannelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"vibrate" -> {
						val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 70L
						vibrate(durationMs)
						result.success(null)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun vibrate(durationMs: Long) {
		window?.decorView?.performHapticFeedback(
			HapticFeedbackConstants.LONG_PRESS,
			HapticFeedbackConstants.FLAG_IGNORE_GLOBAL_SETTING,
		)

		val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
			manager.defaultVibrator
		} else {
			@Suppress("DEPRECATION")
			getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
		}

		if (!vibrator.hasVibrator()) return

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			vibrator.vibrate(
				VibrationEffect.createWaveform(
					longArrayOf(0L, durationMs, 45L, durationMs / 2),
					-1,
				),
			)
		} else {
			@Suppress("DEPRECATION")
			vibrator.vibrate(durationMs + 60L)
		}
	}
}
