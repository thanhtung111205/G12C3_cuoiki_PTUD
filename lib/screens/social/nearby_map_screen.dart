import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../models/nearby_study_peer.dart';
import '../../services/location_service.dart';
import '../../utils/app_colors.dart';
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
    _positionSubscription?.cancel();
    _visibleUsersSubscription?.cancel();
    _currentUserSubscription?.cancel();
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
        return _PeerBottomSheet(
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
                      _BackButtonChip(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoChip(
                          title: 'Bản đồ bạn học gần',
                          subtitle:
                              '${_nearbyPeers.length} người trong bán kính 2km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PrivacySwitchCard(
                        isVisible: _isLocationVisible,
                        isSaving: _isSavingVisibility,
                        onChanged: _toggleVisibility,
                      ),
                    ],
                  ),
                  if (_statusMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    _StatusBanner(message: _statusMessage!),
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
                child: _EmptyNearbyCard(isLocationVisible: _isLocationVisible),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color chipBg = isDark
        ? const Color(0xFF1A1A22).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.lavender.withValues(alpha: 0.7);
    final Color titleColor = isDark ? Colors.white : AppColors.lightText;
    final Color subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.lightTextSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: subtitleColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButtonChip extends StatelessWidget {
  const _BackButtonChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? const Color(0xFF1A1A22).withValues(alpha: 0.94)
          : Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : AppColors.lightText,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _PrivacySwitchCard extends StatelessWidget {
  const _PrivacySwitchCard({
    required this.isVisible,
    required this.isSaving,
    required this.onChanged,
  });

  final bool isVisible;
  final bool isSaving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = isDark
        ? const Color(0xFF1A1A22).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.94);
    final Color border = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : AppColors.lavender.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            isVisible ? 'Hiện' : 'Ẩn',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.lightText,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: isVisible,
            onChanged: isSaving ? null : onChanged,
            activeThumbColor: AppColors.deepPurple,
            activeTrackColor: AppColors.deepPurple.withValues(alpha: 0.28),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A22).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.lavender.withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? Colors.white.withValues(alpha: 0.78)
              : AppColors.lightTextSecondary,
          height: 1.35,
        ),
      ),
    );
  }
}

class _EmptyNearbyCard extends StatelessWidget {
  const _EmptyNearbyCard({required this.isLocationVisible});

  final bool isLocationVisible;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1A22).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.lavender.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.person_search_outlined,
            color: AppColors.deepPurple,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            isLocationVisible
                ? 'Chưa có bạn học nào trong bán kính 2km.'
                : 'Bạn đang ẩn vị trí, nên sẽ không hiển thị với người khác.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.78)
                  : AppColors.lightTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerBottomSheet extends StatelessWidget {
  const _PeerBottomSheet({
    required this.peer,
    required this.distanceMeters,
    required this.onStartChat,
  });

  final NearbyStudyPeer peer;
  final double? distanceMeters;
  final VoidCallback onStartChat;

  String _distanceLabel() {
    final double meters = distanceMeters ?? peer.distanceMeters;
    if (meters == null) return 'Đang tính khoảng cách';

    if (meters < 1000) {
      return 'Cách bạn ${meters.toStringAsFixed(0)}m';
    }

    return 'Cách bạn ${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color panelBg = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final Color panelTitle = isDark ? Colors.white : AppColors.lightText;
    final Color panelSubtle = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PeerAvatar(avatarUrl: peer.avatarUrl),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        peer.displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: panelTitle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _distanceLabel(),
                        style: TextStyle(fontSize: 13, color: panelSubtle),
                      ),
                      const SizedBox(height: 10),
                      _StatusBadge(label: peer.studyStatus),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: onStartChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Bắt đầu trò chuyện',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.avatarUrl});

  final String? avatarUrl;

  bool get _isDataUri => avatarUrl?.startsWith('data:image/') == true;

  @override
  Widget build(BuildContext context) {
    final String? url = avatarUrl?.trim().isNotEmpty == true ? avatarUrl : null;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.lavender.withValues(alpha: 0.55),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.lavender,
        ),
      ),
      child: ClipOval(
        child: url == null
            ? const Icon(Icons.person, color: AppColors.deepPurple, size: 36)
            : _isDataUri
            ? Image.memory(
                base64Decode(url.split(',').last),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: AppColors.deepPurple,
                  size: 36,
                ),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  color: AppColors.deepPurple,
                  size: 36,
                ),
              ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.lavender.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.lightText,
        ),
      ),
    );
  }
}
