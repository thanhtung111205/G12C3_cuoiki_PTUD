import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../models/nearby_study_peer.dart';
import '../../services/location_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/nearby_map_widgets.dart';
import 'chat_room_screen.dart';

class NearbyMapScreen extends StatefulWidget {
  const NearbyMapScreen({super.key, required this.currentUserId});

  final String currentUserId;

  @override
  State<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends State<NearbyMapScreen> {
  static const double _nearbyRadiusMeters = 2000;
  static const double _initialZoom = 16;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = const LocationService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _visibleUsersSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _currentUserSubscription;

  Position? _currentPosition;
  List<NearbyStudyPeer> _visiblePeers = <NearbyStudyPeer>[];
  List<NearbyStudyPeer> _nearbyPeers = <NearbyStudyPeer>[];

  bool _isLoading = true;
  bool _isLocationVisible = true;
  bool _isSavingVisibility = false;
  bool _isMapReady = false;
  String? _errorMessage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _bootstrapNearbyMap();
  }

  @override
  void dispose() {
    // Hủy các subscriptions
    _positionSubscription?.cancel();
    _visibleUsersSubscription?.cancel();
    _currentUserSubscription?.cancel();
    
    // Lưu ý: Chúng tôi NOT xóa vị trí ở đây vì người dùng có thể 
    // quay lại màn hình này. Chỉ xóa khi app thực sự tắt (xem main.dart)
    super.dispose();
  }

  Future<void> _bootstrapNearbyMap() async {
    _safeSetState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final access = await _locationService.ensureLocationAccess();
    if (!access.isGranted) {
      _safeSetState(() {
        _isLoading = false;
        _errorMessage = access.message;
      });
      return;
    }

    try {
      final position = await _locationService.getCurrentPosition();
      _currentPosition = position;
      await _publishCurrentLocation(position);
      _bindRealtimeStreams();
      _recalculateNearbyPeers();

      _safeSetState(() {
        _isLoading = false;
      });
      _moveMapToCurrentPosition();
    } catch (error) {
      _safeSetState(() {
        _isLoading = false;
        _errorMessage =
            'Không thể lấy vị trí hiện tại. Vui lòng kiểm tra GPS và thử lại.\n$error';
      });
    }
  }

  void _bindRealtimeStreams() {
    _currentUserSubscription = _firestore
        .collection('users')
        .doc(widget.currentUserId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;

          final bool visible = (data['isLocationVisible'] as bool?) ?? true;
          if (visible != _isLocationVisible) {
            _safeSetState(() {
              _isLocationVisible = visible;
            });
          }
        });

    _visibleUsersSubscription = _firestore
        .collection('users')
        .where('isLocationVisible', isEqualTo: true)
        .snapshots()
        .listen(
          (snapshot) {
            final List<NearbyStudyPeer> peers = snapshot.docs
                .where((doc) => doc.id != widget.currentUserId)
                .map(_peerFromDocument)
                .whereType<NearbyStudyPeer>()
                .toList();

            _visiblePeers = peers;
            _recalculateNearbyPeers();
          },
          onError: (error) {
            _safeSetState(() {
              _statusMessage =
                  'Không thể đồng bộ danh sách bạn học gần đây: $error';
            });
          },
        );

    _positionSubscription = _locationService.watchPosition().listen((
      position,
    ) async {
      _currentPosition = position;
      await _publishCurrentLocation(position);
      _recalculateNearbyPeers();

      _moveMapToCurrentPosition();
    });
  }

  void _moveMapToCurrentPosition() {
    final Position? currentPosition = _currentPosition;
    if (currentPosition == null || !_isMapReady) return;

    _mapController.move(
      latlng.LatLng(currentPosition.latitude, currentPosition.longitude),
      _initialZoom,
    );
  }

  NearbyStudyPeer? _peerFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final double? latitude = _readDouble(data['latitude']);
    final double? longitude = _readDouble(data['longitude']);

    // Nếu vị trí là null, đồng nghĩa app của người này đã tắt và vị trí bị xóa
    // Không hiển thị người dùng này trên bản đồ
    if (latitude == null || longitude == null) return null;

    return NearbyStudyPeer(
      id: doc.id,
      displayName: _readUserName(data),
      avatarUrl:
          _readString(data['avatarUrl']) ?? _readString(data['photoUrl']),
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
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return null;
  }

  Future<void> _publishCurrentLocation(Position position) async {
    try {
      await _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .set(<String, dynamic>{
            'latitude': position.latitude,
            'longitude': position.longitude,
            'lastLocation': GeoPoint(position.latitude, position.longitude),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      // Firestore write failures should not block map rendering.
    }
  }

  void _recalculateNearbyPeers() {
    final Position? currentPosition = _currentPosition;
    if (currentPosition == null) return;

    final List<NearbyStudyPeer> peers = <NearbyStudyPeer>[];

    for (final peer in _visiblePeers) {
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

    peers.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    _safeSetState(() {
      _nearbyPeers = peers;
    });
  }

  Future<void> _toggleVisibility(bool isVisible) async {
    _safeSetState(() {
      _isLocationVisible = isVisible;
      _isSavingVisibility = true;
      _statusMessage = isVisible
          ? 'Đang bật hiển thị vị trí trên bản đồ.'
          : 'Đang ẩn vị trí của bạn khỏi bản đồ.';
    });

    try {
      await _firestore
          .collection('users')
          .doc(widget.currentUserId)
          .set(<String, dynamic>{
            'isLocationVisible': isVisible,
            'visibilityUpdatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (error) {
      _safeSetState(() {
        _isLocationVisible = !isVisible;
        _statusMessage = 'Không thể cập nhật trạng thái hiển thị: $error';
      });
    } finally {
      _safeSetState(() {
        _isSavingVisibility = false;
      });
    }
  }

  void _safeSetState(VoidCallback callback) {
    if (!mounted) return;
    setState(callback);
  }

  void _openPeerSheet(NearbyStudyPeer peer) {
    final double? distance = _currentPosition == null
        ? null
        : _locationService.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            peer.latitude,
            peer.longitude,
          );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return NearbyPeerBottomSheet(
          peer: peer,
          distanceMeters: distance,
          onStartChat: () {
            Navigator.of(sheetContext).pop();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatRoomScreen(
                  currentUserId: widget.currentUserId,
                  partnerId: peer.id,
                  partnerName: peer.displayName,
                  partnerAvatarUrl: peer.avatarUrl,
                  partnerStatus: peer.studyStatus,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMarker({
    required Color color,
    required double size,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.58),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return _buildFullScreenState(
        title: 'Đang khởi tạo Bản đồ Bạn học ở gần',
        message: 'Đang lấy quyền vị trí và cập nhật dữ liệu xung quanh bạn.',
        child: const CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      final bool gpsIssue = _errorMessage!.contains('GPS');

      return _buildFullScreenState(
        title: 'Không thể mở bản đồ',
        message: _errorMessage!,
        child: ElevatedButton(
          onPressed: () async {
            if (gpsIssue) {
              await _locationService.openLocationSettings();
            } else {
              await _locationService.openAppSettings();
            }
            await _bootstrapNearbyMap();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          child: Text(gpsIssue ? 'Mở cài đặt GPS' : 'Mở cài đặt quyền'),
        ),
      );
    }

    final List<Marker> markers = <Marker>[
      Marker(
        point: latlng.LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: _buildMarker(
          color: AppColors.deepPurple,
          size: 38,
          icon: Icons.my_location,
        ),
      ),
      ..._nearbyPeers.map(
        (peer) => Marker(
          point: latlng.LatLng(peer.latitude, peer.longitude),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          child: _buildMarker(
            color: AppColors.lavender,
            size: 42,
            icon: Icons.person,
            onTap: () => _openPeerSheet(peer),
          ),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101014) : Colors.white,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: latlng.LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                initialZoom: _initialZoom,
                onMapReady: () {
                  _isMapReady = true;
                  _moveMapToCurrentPosition();
                },
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'cki_demo',
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      NearbyMapBackButtonChip(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: NearbyMapInfoChip(
                          title: 'Bản đồ bạn học gần',
                          subtitle:
                              '${_nearbyPeers.length} người trong bán kính 2km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      NearbyMapPrivacySwitchCard(
                        isVisible: _isLocationVisible,
                        isSaving: _isSavingVisibility,
                        onChanged: _toggleVisibility,
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    NearbyMapStatusBanner(message: _statusMessage!),
                  ],
                ],
              ),
            ),
          ),
          if (_nearbyPeers.isEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: NearbyMapEmptyNearbyCard(
                  isLocationVisible: _isLocationVisible,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
        foregroundColor: isDark ? AppColors.periwinkle : AppColors.deepPurple,
        onPressed: _bootstrapNearbyMap,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildFullScreenState({
    required String title,
    required String message,
    required Widget child,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color pageBg = isDark
        ? const Color(0xFF101014)
        : const Color(0xFFF7F4FF);
    final Color circleBg = isDark
        ? const Color(0xFF1D1A2B)
        : AppColors.lavender;
    final Color titleColor = isDark ? Colors.white : AppColors.lightText;
    final Color messageColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: circleBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.map_outlined,
                  color: AppColors.deepPurple,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: messageColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
