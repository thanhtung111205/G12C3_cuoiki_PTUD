import 'package:geolocator/geolocator.dart';

enum LocationAccessState {
	granted,
	serviceDisabled,
	denied,
	deniedForever,
}

class LocationAccessResult {
	const LocationAccessResult({
		required this.state,
		required this.message,
	});

	final LocationAccessState state;
	final String message;

	bool get isGranted => state == LocationAccessState.granted;
}

class LocationService {
	const LocationService();

	Future<LocationAccessResult> ensureLocationAccess() async {
		final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
		if (!serviceEnabled) {
			return const LocationAccessResult(
				state: LocationAccessState.serviceDisabled,
				message:
						'Dịch vụ vị trí đang tắt. Vui lòng bật GPS để xem bạn học ở gần.',
			);
		}

		LocationPermission permission = await Geolocator.checkPermission();
		if (permission == LocationPermission.denied) {
			permission = await Geolocator.requestPermission();
		}

		if (permission == LocationPermission.denied) {
			return const LocationAccessResult(
				state: LocationAccessState.denied,
				message:
						'Ứng dụng cần quyền vị trí để hiển thị bạn học ở gần. Vui lòng cấp quyền và thử lại.',
			);
		}

		if (permission == LocationPermission.deniedForever) {
			return const LocationAccessResult(
				state: LocationAccessState.deniedForever,
				message:
						'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy mở cài đặt ứng dụng để cấp lại quyền.',
			);
		}

		return const LocationAccessResult(
			state: LocationAccessState.granted,
			message: '',
		);
	}

	Future<Position> getCurrentPosition() {
		return Geolocator.getCurrentPosition(
			desiredAccuracy: LocationAccuracy.high,
		).timeout(const Duration(seconds: 10));
	}

	Stream<Position> watchPosition() {
		return Geolocator.getPositionStream(
			locationSettings: const LocationSettings(
				accuracy: LocationAccuracy.best,
				distanceFilter: 10,
			),
		);
	}

	double distanceBetween(
		double startLatitude,
		double startLongitude,
		double endLatitude,
		double endLongitude,
	) {
		return Geolocator.distanceBetween(
			startLatitude,
			startLongitude,
			endLatitude,
			endLongitude,
		);
	}

	Future<bool> openLocationSettings() {
		return Geolocator.openLocationSettings();
	}

	Future<bool> openAppSettings() {
		return Geolocator.openAppSettings();
	}
}