import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key, required this.currentUserId});

  /// uid của user hiện tại, trùng với document id trong collection `users`.
  final String currentUserId;

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final MapController _mapController = MapController();
  Position? _currentPosition;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;

  final List<Marker> _nearbyMarkers = <Marker>[];

  bool _isLoading = true;
  String? _errorMessage;
  String? _firestoreError;

  // Demo markers used when Firestore is unavailable
  bool _usingDemoMarkers = false;

  static const double _nearbyRadiusMeters = 2000; // 2km
  static const double _initialZoom = 15;

  @override
  void initState() {
    super.initState();
    _initLocationAndStreams();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _usersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocationAndStreams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Kiểm tra dịch vụ vị trí
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Dịch vụ vị trí đang tắt. Vui lòng bật GPS/location trên thiết bị.';
        });
        return;
      }

      // 2. Kiểm tra & xin quyền truy cập vị trí
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Ứng dụng không có quyền truy cập vị trí. Vui lòng cấp quyền trong phần Cài đặt.';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Quyền vị trí đã bị từ chối vĩnh viễn. Vui lòng vào Cài đặt hệ thống để cho phép lại.';
        });
        return;
      }

      // 3. Lấy vị trí hiện tại lần đầu (có timeout để tránh treo trên emulator không có GPS)
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 10));

        _currentPosition = position;
        await _updateUserLocationInFirestore(position);

        setState(() {
          _isLoading = false;
        });
      } on TimeoutException catch (_) {
        // Emulator or device không trả về vị trí nhanh — fallback sang demo location
        debugPrint(
          'Geolocator.getCurrentPosition timed out — using demo location',
        );
        _usingDemoMarkers = true;
        // đặt default location (ví dụ trung tâm Hà Nội) để map hiển thị
        _currentPosition = Position(
          longitude: 105.8342,
          latitude: 21.0278,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          // required by Position constructor
          altitudeAccuracy: 0.0,
          headingAccuracy: 0.0,
        );

        setState(() {
          _isLoading = false;
        });

        // tạo demo markers ngay
        _generateDemoMarkersIfNeeded();
      }

      // 4. Lắng nghe stream vị trí với khoảng cách tối thiểu 10m
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((Position newPosition) async {
            _currentPosition = newPosition;
            await _updateUserLocationInFirestore(newPosition);

            _mapController.move(
              latlng.LatLng(newPosition.latitude, newPosition.longitude),
              _initialZoom,
            );

            setState(() {
              // Cập nhật để tính lại khoảng cách và vẽ marker nếu cần.
            });
          });

      // 5. Lắng nghe dữ liệu realtime từ Firestore
      _usersSubscription = _firestore
          .collection('users')
          .snapshots()
          .listen(
            _onUsersSnapshot,
            onError: (e) {
              setState(() {
                _firestoreError = e?.toString();
                _usingDemoMarkers = true;
                _generateDemoMarkersIfNeeded();
              });
            },
          );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Đã xảy ra lỗi khi khởi tạo vị trí: $e';
      });
    }
  }

  Future<void> _updateUserLocationInFirestore(Position position) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .set(<String, dynamic>{
            'latitude': position.latitude,
            'longitude': position.longitude,
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      // Có thể log lỗi nếu cần, nhưng không chặn UI.
    }
  }

  void _onUsersSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (_currentPosition == null) {
      return;
    }

    final List<Marker> newMarkers = <Marker>[];
    final double myLat = _currentPosition!.latitude;
    final double myLng = _currentPosition!.longitude;

    for (final doc in snapshot.docs) {
      if (doc.id == widget.currentUserId) {
        // Bỏ qua chính mình
        continue;
      }

      final data = doc.data();
      final double? lat = (data['latitude'] as num?)?.toDouble();
      final double? lng = (data['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(myLat, myLng, lat, lng);

      if (distance <= _nearbyRadiusMeters) {
        final String name = (data['name'] as String?) ?? 'Bạn học gần đây';
        final String studyStatus =
            (data['study_status'] as String?) ?? 'Chưa có trạng thái học tập';

        final marker = Marker(
          point: latlng.LatLng(lat, lng),
          width: 40,
          height: 40,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {
              _showUserDetailBottomSheet(name: name, studyStatus: studyStatus);
            },
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
          ),
        );

        newMarkers.add(marker);
      }
    }

    setState(() {
      _nearbyMarkers
        ..clear()
        ..addAll(newMarkers);
      // If no real markers and Firestore errored, generate demo markers
      if (_nearbyMarkers.isEmpty && _usingDemoMarkers) {
        _generateDemoMarkersIfNeeded();
      }
    });
  }

  void _generateDemoMarkersIfNeeded() {
    if (_currentPosition == null) return;
    if (!_usingDemoMarkers) return;
    // create 3 demo users around current position (~within 200-1000m)
    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;
    final List<Marker> demo = <Marker>[];

    final offsets = <double>[0.0015, -0.0012, 0.0009];
    final names = <String>['Demo A', 'Demo B', 'Demo C'];
    final statuses = <String>[
      'Ôn thi Toán',
      'Luyện nói Tiếng Anh',
      'Làm bài tập Lập trình',
    ];

    for (var i = 0; i < offsets.length; i++) {
      demo.add(
        Marker(
          point: latlng.LatLng(
            lat + offsets[i],
            lng + offsets[(i + 1) % offsets.length],
          ),
          width: 40,
          height: 40,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () => _showUserDetailBottomSheet(
              name: names[i],
              studyStatus: statuses[i],
            ),
            child: const Icon(Icons.location_on, color: Colors.green, size: 36),
          ),
        ),
      );
    }

    setState(() {
      _nearbyMarkers
        ..clear()
        ..addAll(demo);
    });
  }

  void _showUserDetailBottomSheet({
    required String name,
    required String studyStatus,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(studyStatus, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nearby Study Partners'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nearby Study Partners'),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initLocationAndStreams,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nearby Study Partners'),
          centerTitle: true,
        ),
        body: const Center(child: Text('Không thể lấy vị trí hiện tại.')),
      );
    }

    final List<Marker> allMarkers = <Marker>[
      // Marker đại diện cho vị trí của chính người dùng.
      Marker(
        point: latlng.LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        width: 40,
        height: 40,
        alignment: Alignment.bottomCenter,
        child: const Icon(
          Icons.person_pin_circle,
          color: Colors.blue,
          size: 38,
        ),
      ),
      ..._nearbyMarkers,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Study Partners'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Locate me',
            onPressed: _forceRefreshPosition,
            icon: const Icon(Icons.my_location),
          ),
          IconButton(
            tooltip: 'Open location settings',
            onPressed: () async {
              await Geolocator.openLocationSettings();
            },
            icon: const Icon(Icons.location_searching),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latlng.LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              initialZoom: _initialZoom,
            ),
            children: <Widget>[
              TileLayer(
                // Use CartoDB basemap for demo (more suitable for small demos).
                urlTemplate:
                    'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                subdomains: const <String>['a', 'b', 'c', 'd'],
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent':
                        'cki_demo/1.0 (contact: your-email@example.com)',
                  },
                ),
              ),
              MarkerLayer(markers: allMarkers),
            ],
          ),
          if (_firestoreError != null)
            Positioned(
              left: 16,
              right: 16,
              top: 80,
              child: Card(
                color: Colors.orange.withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Firestore warning: $_firestoreError',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          if (_nearbyMarkers.isEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Colors.white.withOpacity(0.9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Hiện chưa có bạn học nào trong bán kính 2km. Hãy rủ thêm bạn bè mở ứng dụng để học nhóm nhé!',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          // Show current user's coordinates in the top-left corner for easy verification
          Positioned(
            left: 12,
            top: 72,
            child: Card(
              color: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn: ${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cập nhật: ${_currentPosition!.timestamp.toLocal().toString().split('.').first}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _forceRefreshPosition() async {
    try {
      setState(() => _isLoading = true);
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      ).timeout(const Duration(seconds: 10));

      _currentPosition = pos;
      // update firestore & map
      await _updateUserLocationInFirestore(pos);
      _mapController.move(
        latlng.LatLng(pos.latitude, pos.longitude),
        _initialZoom,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _usingDemoMarkers = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vị trí hiện tại: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể lấy vị trí: $e')));
      }
    }
  }
}
