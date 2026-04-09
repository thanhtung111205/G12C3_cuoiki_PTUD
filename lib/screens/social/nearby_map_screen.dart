import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:provider/provider.dart';

import '../../models/nearby_study_peer.dart';
import '../../providers/location_provider.dart';
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
  static const double _initialZoom = 16;

  final MapController _mapController = MapController();
  bool _isMapReady = false;
  String? _lastMovedPositionKey;

  LocationProvider get _locationProvider => context.read<LocationProvider>();

  @override
  void initState() {
    super.initState();
    _locationProvider.bootstrapNearbyMap(widget.currentUserId);
  }

  Future<void> _bootstrapNearbyMap() async {
    await _locationProvider.bootstrapNearbyMap(widget.currentUserId);
  }

  Future<void> _toggleVisibility(bool isVisible) async {
    await _locationProvider.toggleVisibility(widget.currentUserId, isVisible);
  }

  void _openPeerSheet(NearbyStudyPeer peer) {
    final LocationProvider locationProvider = context.read<LocationProvider>();
    final Position? currentPosition = locationProvider.currentPosition;
    final double? distance = currentPosition == null
        ? null
        : locationProvider.distanceBetween(
            currentPosition.latitude,
            currentPosition.longitude,
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
    final LocationProvider locationProvider = context.watch<LocationProvider>();
    final Position? currentPosition = locationProvider.currentPosition;

    _moveMapToCurrentPosition(currentPosition);

    if (locationProvider.isLoading) {
      return _buildFullScreenState(
        title: 'Đang khởi tạo Bản đồ Bạn học ở gần',
        message: 'Đang lấy quyền vị trí và cập nhật dữ liệu xung quanh bạn.',
        child: const CircularProgressIndicator(),
      );
    }

    if (locationProvider.errorMessage != null) {
      final bool gpsIssue = locationProvider.errorMessage!.contains('GPS');

      return _buildFullScreenState(
        title: 'Không thể mở bản đồ',
        message: locationProvider.errorMessage!,
        child: ElevatedButton(
          onPressed: () async {
            if (gpsIssue) {
              await locationProvider.openLocationSettings();
            } else {
              await locationProvider.openAppSettings();
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
          currentPosition!.latitude,
          currentPosition!.longitude,
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
      ...locationProvider.nearbyPeers.map(
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
                  currentPosition!.latitude,
                  currentPosition!.longitude,
                ),
                initialZoom: _initialZoom,
                onMapReady: () {
                  _isMapReady = true;
                  _moveMapToCurrentPosition(currentPosition);
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
                              '${locationProvider.nearbyPeers.length} người trong bán kính 2km',
                        ),
                      ),
                      const SizedBox(width: 12),
                      NearbyMapPrivacySwitchCard(
                        isVisible: locationProvider.isLocationVisible,
                        isSaving: locationProvider.isSavingVisibility,
                        onChanged: _toggleVisibility,
                      ),
                    ],
                  ),
                  if (locationProvider.statusMessage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    NearbyMapStatusBanner(message: locationProvider.statusMessage!),
                  ],
                ],
              ),
            ),
          ),
          if (locationProvider.nearbyPeers.isEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: NearbyMapEmptyNearbyCard(
                  isLocationVisible: locationProvider.isLocationVisible,
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

  void _moveMapToCurrentPosition(Position? currentPosition) {
    if (currentPosition == null || !_isMapReady) return;

    final String positionKey =
        '${currentPosition.latitude.toStringAsFixed(6)},${currentPosition.longitude.toStringAsFixed(6)}';
    if (_lastMovedPositionKey == positionKey) return;
    _lastMovedPositionKey = positionKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isMapReady) return;

      _mapController.move(
        latlng.LatLng(currentPosition.latitude, currentPosition.longitude),
        _initialZoom,
      );
    });
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
