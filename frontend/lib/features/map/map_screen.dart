import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../providers/location_provider.dart';
import '../../providers/search_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  bool _locationDialogShown = false;
  bool _mapReady = false;

  // Places state
  Set<Marker>                 _markers          = {};
  List<Map<String, dynamic>>  _places           = [];
  bool                        _isLoadingPlaces  = false;
  int                         _placeCount       = -1; // -1 = not yet searched

  @override
  Widget build(BuildContext context) {
    final locationAsync = ref.watch(locationProvider);
    final searchState   = ref.watch(searchProvider);
    final result        = searchState.result;

    return locationAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Proximity Map')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildMap(context, null, result),
      data: (position) {
        if (position == null && !_locationDialogShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _locationDialogShown = true);
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Location needed'),
                content: const Text(
                  'Enable location permission in Settings to see your position on the map.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          });
        }
        return _buildMap(
          context,
          position != null ? LatLng(position.latitude, position.longitude) : null,
          result,
        );
      },
    );
  }

  Widget _buildMap(BuildContext context, LatLng? position, dynamic result) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    // Display label: show product name so user knows what they last searched
    final displayQuery = result?.tags.productName ?? result?.tags.searchQuery ?? '';

    // Raw tags sent to backend — it resolves the right store type server-side
    final placeCategory    = result?.tags.category    ?? '';
    final placeProductName = result?.tags.productName ?? displayQuery;

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map fills screen ───────────────────────────────────────
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: position ?? const LatLng(0, 0),
                initialZoom: position != null ? 14 : 2,
                onMapReady: () {
                  if (!mounted) return;
                  setState(() => _mapReady = true);
                  if (_markers.isNotEmpty) {
                    _fitMarkers();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.go4app.go4',
                  maxZoom: 19,
                ),
                if (position != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: position,
                        width: 36,
                        height: 36,
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.blue,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                if (_markers.isNotEmpty)
                  MarkerLayer(
                    markers: _markers.toList(),
                  ),
              ],
            ),
          ),

          // ── Back button overlay ───────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  FloatingActionButton.small(
                    heroTag: 'mapBack',
                    backgroundColor: Colors.black54,
                    onPressed: () => Navigator.maybePop(context),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  // "View Results" button — shown when user came from a search
                  if (result != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FloatingActionButton.extended(
                        heroTag: 'mapResults',
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        icon: const Icon(Icons.list_alt, size: 18),
                        label: const Text('Results',
                            style: TextStyle(fontSize: 13)),
                        onPressed: () => context.push('/results'),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Bottom panel ──────────────────────────────────────────────────
          if (result != null && displayQuery.isNotEmpty)
            DraggableScrollableSheet(
              initialChildSize: 0.20,
              minChildSize: 0.12,
              maxChildSize: 0.65,
              builder: (ctx, scrollCtrl) => Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white24
                              : AppTheme.surfaceBorderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Last searched product chip
                    Center(
                      child: Chip(
                        avatar: const Icon(Icons.search, size: 16),
                        label: Text(
                          displayQuery,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Find nearby stores button
                    ElevatedButton.icon(
                      icon: _isLoadingPlaces
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.store_mall_directory_outlined),
                      label: Text(_isLoadingPlaces
                          ? 'Searching…'
                          : _placeCount < 0
                              ? 'Find nearby stores'
                              : 'Refresh stores'),
                      onPressed: _isLoadingPlaces
                          ? null
                          : () => _loadNearbyPlaces(
                                position,
                                placeCategory,
                                placeProductName,
                              ),
                    ),

                    // Store list
                    if (_placeCount == 0) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'No stores found nearby.',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.onSurfaceLowLight,
                              fontSize: 13),
                        ),
                      ),
                    ] else if (_places.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        '$_placeCount store${_placeCount == 1 ? '' : 's'} nearby',
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._places.map(
                        (p) => _StoreCard(
                          place: p,
                          onDirections: () => _getDirections(p),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadNearbyPlaces(
      LatLng? position, String category, String productName) async {
    if (_isLoadingPlaces) return;
    setState(() {
      _isLoadingPlaces = true;
      _markers = {};
      _places  = [];
      _placeCount = -1;
    });

    try {
      final places = await ApiClient.instance.getNearbyPlaces(
        category:    category,
        productName: productName,
        lat: position?.latitude,
        lng: position?.longitude,
      );

      final newMarkers = <Marker>{};
      for (final p in places) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        newMarkers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 42,
            height: 42,
            child: Tooltip(
              message: [
                p['name'] as String? ?? 'Store',
                if ((p['address'] as String?)?.isNotEmpty ?? false)
                  p['address'] as String,
              ].whereType<String>().join('\n'),
              child: const Icon(
                Icons.place,
                color: Colors.red,
                size: 34,
              ),
            ),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _markers    = newMarkers;
          _places     = places;
          _placeCount = newMarkers.length;
          _isLoadingPlaces = false;
        });

        // Zoom to fit all markers if we found any.
        if (newMarkers.isNotEmpty && _mapReady) {
          _fitMarkers();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPlaces = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  void _fitMarkers() {
    if (!_mapReady || _markers.isEmpty) return;

    final points = _markers.map((marker) => marker.point).toList();
    if (points.length == 1) {
      _mapController.move(points.first, 15);
      return;
    }

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(80),
        maxZoom: 16,
      ),
    );
  }

  // ── Directions ─────────────────────────────────────────────────────────────

  Future<void> _getDirections(Map<String, dynamic> place) async {
    final lat  = (place['lat']  as num?)?.toDouble();
    final lng  = (place['lng']  as num?)?.toDouble();
    final name = Uri.encodeComponent(place['name'] as String? ?? 'store');

    if (lat == null || lng == null) return;

    final geoUri  = Uri.parse('geo:$lat,$lng?q=$name');
    final mapsUri = Uri.parse('https://maps.google.com/?q=$name&ll=$lat,$lng');

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
    } else {
      await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─── Store card ───────────────────────────────────────────────────────────────

class _StoreCard extends StatefulWidget {
  final Map<String, dynamic> place;
  final VoidCallback onDirections;

  const _StoreCard({required this.place, required this.onDirections});

  @override
  State<_StoreCard> createState() => _StoreCardState();
}

class _StoreCardState extends State<_StoreCard> {
  bool _expanded = false;
  bool _loadingDetails = false;
  Map<String, dynamic>? _details;

  Future<void> _loadDetails() async {
    final placeId = widget.place['placeId'] as String?;
    if (placeId == null || _details != null) return;
    setState(() => _loadingDetails = true);
    try {
      final d = await ApiClient.instance.getPlaceDetails(placeId);
      if (mounted) setState(() { _details = d; _loadingDetails = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final name    = widget.place['name']    as String? ?? 'Store';
    final address = widget.place['address'] as String? ?? '';
    final rating  = (widget.place['rating'] as num?)?.toDouble();
    final openNow = (_details?['openNow'] ?? widget.place['openNow']) as bool?;

    final weekdayText = (_details?['weekdayText'] as List<dynamic>?)
        ?.whereType<String>()
        .toList();
    final phone   = _details?['phone']   as String?;
    final website = _details?['website'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Store info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                              fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Open / closed badge
                          if (openNow != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (openNow ? Colors.green : Colors.red)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                openNow ? 'Open' : 'Closed',
                                style: TextStyle(
                                  color: openNow ? Colors.green : Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (openNow != null && rating != null)
                            const SizedBox(width: 6),
                          // Rating
                          if (rating != null) ...[
                            const Icon(Icons.star,
                                size: 12, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              rating.toStringAsFixed(1),
                              style: TextStyle(
                                  color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                                  fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Action buttons
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.accent, width: 1),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.directions, size: 14),
                      label: const Text('Directions',
                          style: TextStyle(fontSize: 12)),
                      onPressed: widget.onDirections,
                    ),
                    const SizedBox(height: 6),
                    // Show/hide hours button
                    if (widget.place['placeId'] != null)
                      GestureDetector(
                        onTap: () {
                          setState(() => _expanded = !_expanded);
                          if (_expanded) _loadDetails();
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _expanded ? 'Hide' : 'Hours',
                              style: TextStyle(
                                  color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                                  fontSize: 11),
                            ),
                            Icon(
                              _expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Expanded details ──────────────────────────────────────────────
          if (_expanded) ...[
            Divider(
                height: 1,
                color: Theme.of(context).dividerColor),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _loadingDetails
                  ? Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Phone
                        if (phone != null) ...[
                          Row(
                            children: [
                              Icon(Icons.phone,
                                  size: 13,
                                  color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
                              const SizedBox(width: 6),
                              Text(
                                phone,
                                style: TextStyle(
                                    color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Website
                        if (website != null) ...[
                          Row(
                            children: [
                              Icon(Icons.language,
                                  size: 13,
                                  color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  website,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        // Weekday hours
                        if (weekdayText != null && weekdayText.isNotEmpty) ...[
                          Text(
                            'Opening hours',
                            style: TextStyle(
                              color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...weekdayText.map((line) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  line,
                                  style: TextStyle(
                                      color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                                      fontSize: 11),
                                ),
                              )),
                        ] else if (!_loadingDetails)
                          Text(
                            'Hours not available',
                            style: TextStyle(
                                color: isDark ? AppTheme.onSurfaceMid : AppTheme.onSurfaceMidLight,
                                fontSize: 11),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
