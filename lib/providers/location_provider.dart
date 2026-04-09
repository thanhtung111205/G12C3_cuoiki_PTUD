import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/nearby_study_peer.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
	LocationProvider({LocationService? locationService})
		: _locationService = locationService ?? const LocationService();

	static const double _nearbyRadiusMeters = 2000;

	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;
	final LocationService _locationService;

	StreamSubscription<Position>? _positionSubscription;
	StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
	_visibleUsersSubscription;
	StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
	_currentUserSubscription;

	String? _currentUserId;
	Position? _currentPosition;
	final List<NearbyStudyPeer> _visiblePeers = <NearbyStudyPeer>[];
	final List<NearbyStudyPeer> _nearbyPeers = <NearbyStudyPeer>[];
	bool _isLocationVisible = true;
	bool _isLoading = true;
	bool _isSavingVisibility = false;
	String? _errorMessage;
	String? _statusMessage;
	bool _isDisposed = false;

	String? get currentUserId => _currentUserId ?? _auth.currentUser?.uid;

	Position? get currentPosition => _currentPosition;
	bool get isLocationVisible => _isLocationVisible;
	bool get isLoading => _isLoading;
	bool get isSavingVisibility => _isSavingVisibility;
	String? get errorMessage => _errorMessage;
	String? get statusMessage => _statusMessage;

	List<NearbyStudyPeer> get visiblePeers => List<NearbyStudyPeer>.unmodifiable(
		_visiblePeers,
	);

	List<NearbyStudyPeer> get nearbyPeers => List<NearbyStudyPeer>.unmodifiable(
		_nearbyPeers,
	);

	Future<void> bootstrapNearbyMap(String userId) async {
		if (userId.trim().isEmpty) return;

		if (_currentUserId != userId) {
			_clearSubscriptions();
			_currentUserId = userId;
		}

		_setLoading(true);
		_setErrorMessage(null);
		_setStatusMessage(null);

		final LocationAccessResult access =
				await _locationService.ensureLocationAccess();
		if (!access.isGranted) {
			_setLoading(false);
			_setErrorMessage(access.message);
			return;
		}

		try {
			final Position position = await _locationService.getCurrentPosition();
			_currentPosition = position;
			_notify();

			await _publishCurrentLocation(position);
			_bindRealtimeStreams(userId);
			_recalculateNearbyPeers();

			_setLoading(false);
		} catch (error) {
			_setLoading(false);
			_setErrorMessage(
				'Không thể lấy vị trí hiện tại. Vui lòng kiểm tra GPS và thử lại.\n$error',
			);
		}
	}

	Future<void> refresh() async {
		final String? userId = currentUserId;
		if (userId == null) return;
		await bootstrapNearbyMap(userId);
	}

	Future<void> toggleVisibility(String userId, bool isVisible) async {
		if (userId.trim().isEmpty) return;

		_isLocationVisible = isVisible;
		_isSavingVisibility = true;
		_statusMessage = isVisible
				? 'Đang bật hiển thị vị trí trên bản đồ.'
				: 'Đang ẩn vị trí của bạn khỏi bản đồ.';
		_notify();

		try {
			await _firestore.collection('users').doc(userId).set(<String, dynamic>{
				'isLocationVisible': isVisible,
				'visibilityUpdatedAt': FieldValue.serverTimestamp(),
			}, SetOptions(merge: true));
		} catch (error) {
			_isLocationVisible = !isVisible;
			_statusMessage = 'Không thể cập nhật trạng thái hiển thị: $error';
			_notify();
		} finally {
			_isSavingVisibility = false;
			_notify();
		}
	}

	Future<bool> openLocationSettings() {
		return _locationService.openLocationSettings();
	}

	Future<bool> openAppSettings() {
		return _locationService.openAppSettings();
	}

	double distanceBetween(
		double startLatitude,
		double startLongitude,
		double endLatitude,
		double endLongitude,
	) {
		return _locationService.distanceBetween(
			startLatitude,
			startLongitude,
			endLatitude,
			endLongitude,
		);
	}

	void _bindRealtimeStreams(String userId) {
		_currentUserSubscription?.cancel();
		_visibleUsersSubscription?.cancel();
		_positionSubscription?.cancel();

		_currentUserSubscription = _firestore
				.collection('users')
				.doc(userId)
				.snapshots()
				.listen((snapshot) {
					final data = snapshot.data();
					if (data == null) return;

					final bool visible = (data['isLocationVisible'] as bool?) ?? true;
					if (visible != _isLocationVisible) {
						_isLocationVisible = visible;
						_notify();
					}
				});

		_visibleUsersSubscription = _firestore
				.collection('users')
				.where('isLocationVisible', isEqualTo: true)
				.snapshots()
				.listen(
					(snapshot) {
						final List<NearbyStudyPeer> peers = snapshot.docs
								.where((doc) => doc.id != userId)
								.map(_peerFromDocument)
								.whereType<NearbyStudyPeer>()
								.toList();

						_visiblePeers
							..clear()
							..addAll(peers);
						_recalculateNearbyPeers();
					},
					onError: (error) {
						_statusMessage = 'Không thể đồng bộ danh sách bạn học gần đây: $error';
						_notify();
					},
				);

		_positionSubscription = _locationService.watchPosition().listen((
			position,
		) async {
			_currentPosition = position;
			_notify();
			await _publishCurrentLocation(position);
			_recalculateNearbyPeers();
		});
	}

	Future<void> _publishCurrentLocation(Position position) async {
		final String? userId = currentUserId;
		if (userId == null) return;

		try {
			await _firestore.collection('users').doc(userId).set(<String, dynamic>{
				'latitude': position.latitude,
				'longitude': position.longitude,
				'lastLocation': GeoPoint(position.latitude, position.longitude),
				'lastUpdated': FieldValue.serverTimestamp(),
			}, SetOptions(merge: true));
		} catch (_) {
			// Firestore write failures should not block the map flow.
		}
	}

	void _recalculateNearbyPeers() {
		final Position? currentPosition = _currentPosition;
		if (currentPosition == null) return;

		final List<NearbyStudyPeer> peers = <NearbyStudyPeer>[];

		for (final NearbyStudyPeer peer in _visiblePeers) {
			final double distance = _locationService.distanceBetween(
				currentPosition.latitude,
				currentPosition.longitude,
				peer.latitude,
				peer.longitude,
			);

			if (distance <= _nearbyRadiusMeters) {
				peers.add(peer.copyWith(distanceMeters: distance));
			}
		}

		peers.sort((NearbyStudyPeer a, NearbyStudyPeer b) =>
				a.distanceMeters.compareTo(b.distanceMeters));

		_nearbyPeers
			..clear()
			..addAll(peers);
		_notify();
	}

	NearbyStudyPeer? peerFromDocument(
		QueryDocumentSnapshot<Map<String, dynamic>> doc,
	) {
		return _peerFromDocument(doc);
	}

	NearbyStudyPeer? _peerFromDocument(
		QueryDocumentSnapshot<Map<String, dynamic>> doc,
	) {
		final Map<String, dynamic> data = doc.data();
		final double? latitude = _readDouble(data['latitude']);
		final double? longitude = _readDouble(data['longitude']);
		if (latitude == null || longitude == null) return null;

		return NearbyStudyPeer(
			id: doc.id,
			displayName: _readUserName(data),
			avatarUrl: _readString(data['avatarUrl']) ?? _readString(data['photoUrl']),
			studyStatus: _readStudyStatus(data),
			latitude: latitude,
			longitude: longitude,
			distanceMeters: 0,
		);
	}

	String _readUserName(Map<String, dynamic> data) {
		final String? displayName = _readString(data['displayName']);
		final String? legacyName = _readString(data['name']);
		final String? email = _readString(data['email']);

		if (displayName?.isNotEmpty == true) return displayName!;
		if (legacyName?.isNotEmpty == true) return legacyName!;
		if (email?.contains('@') == true) return email!.split('@').first;
		return 'Bạn học gần đây';
	}

	String _readStudyStatus(Map<String, dynamic> data) {
		final String? studyStatus = _readString(data['study_status']);
		final String? legacyStatus = _readString(data['studyStatus']);
		final String? status = _readString(data['status']);

		if (studyStatus?.isNotEmpty == true) return studyStatus!;
		if (legacyStatus?.isNotEmpty == true) return legacyStatus!;
		if (status?.isNotEmpty == true) return status!;
		return 'Đang online';
	}

	String? _readString(dynamic value) {
		if (value is String) {
			final String trimmed = value.trim();
			return trimmed.isEmpty ? null : trimmed;
		}
		return null;
	}

	double? _readDouble(dynamic value) {
		if (value is num) return value.toDouble();
		return null;
	}

	void _clearSubscriptions() {
		_currentUserSubscription?.cancel();
		_currentUserSubscription = null;

		_visibleUsersSubscription?.cancel();
		_visibleUsersSubscription = null;

		_positionSubscription?.cancel();
		_positionSubscription = null;

		_visiblePeers.clear();
		_nearbyPeers.clear();
	}

	void _setLoading(bool value) {
		_isLoading = value;
		_notify();
	}

	void _setErrorMessage(String? message) {
		_errorMessage = message;
		_notify();
	}

	void _setStatusMessage(String? message) {
		_statusMessage = message;
		_notify();
	}

	void _notify() {
		if (_isDisposed) return;
		notifyListeners();
	}

	void clear() {
		_clearSubscriptions();
		_currentUserId = null;
		_currentPosition = null;
		_isLocationVisible = true;
		_isLoading = false;
		_isSavingVisibility = false;
		_errorMessage = null;
		_statusMessage = null;
		_notify();
	}

	@override
	void dispose() {
		_isDisposed = true;
		_clearSubscriptions();
		super.dispose();
	}
}