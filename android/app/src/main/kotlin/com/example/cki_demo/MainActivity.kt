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
						val durationMs = call.argument<Int>("durationMs")?.toLong() ?: 150L
						vibrate(durationMs)
						result.success(null)
					}

					else -> result.notImplemented()
				}
			}
	}

	private fun vibrate(durationMs: Long) {
		// Kích hoạt phản hồi xúc giác mạnh hơn từ hệ thống
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
			// Tạo kiểu rung "kép" mạnh mẽ với biên độ tối đa (255)
			// timings: nghỉ 0ms, rung durationMs, nghỉ 50ms, rung tiếp durationMs
			val timings = longArrayOf(0L, durationMs, 50L, durationMs)
			val amplitudes = intArrayOf(0, 255, 0, 255) // 255 là mức rung mạnh nhất
			
			vibrator.vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1))
		} else {
			@Suppress("DEPRECATION")
			vibrator.vibrate(durationMs + 100L)
		}
	}
}
