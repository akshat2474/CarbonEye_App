import 'dart:math';
import 'package:carboneye/screens/all_alerts_screen.dart';
import 'package:carboneye/api_service.dart';
import 'package:carboneye/constants.dart';
import 'package:carboneye/widgets/dashboard_item.dart';
import 'package:carboneye/widgets/map_preview.dart';
import 'package:carboneye/widgets/neu_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  String _selectedMapFilter = 'Satellite';
  final List<Map<String, dynamic>> _detections = [];
  bool _isLoading = false;
  DateTime _lastSynced = DateTime.now();
  WatchlistItem? _activeWatchlistItem;
  String? _recentPeriod;
  String? _pastPeriod;

  bool _isSelectionMode = false;
  List<LatLng> _selectionPoints = [];


  @override
  void initState() {
    super.initState();
  }

  final List<WatchlistItem> _watchlistRegions = [
    WatchlistItem(
        name: 'Amazonas, Brazil',
        coordinates: const LatLng(-3.46, -62.21),
        bbox: [-62.41, -3.66, -62.01, -3.26]),
    WatchlistItem(
        name: 'Jim Corbett National Park, India',
        coordinates: const LatLng(29.53, 78.77),
        bbox: [78.57, 29.33, 78.97, 29.73]),
    WatchlistItem(
        name: 'Congo Basin, DRC',
        coordinates: const LatLng(0.5, 23.5),
        bbox: [23.3, 0.3, 23.7, 0.7]),
    WatchlistItem(
        name: 'Serengeti National Park, Tanzania',
        coordinates: const LatLng(-2.33, 34.83),
        bbox: [34.63, -2.53, 35.03, -2.13]),
    WatchlistItem(
        name: 'Sundarbans National Park, India',
        coordinates: const LatLng(21.94, 88.85),
        bbox: [88.65, 21.74, 89.05, 22.14]),
  ];

  final Map<String, dynamic> _availableForestsData = {
    'Ranthambore National Park, India': {
      'coordinates': const LatLng(26.01, 76.50),
      'bbox': [76.30, 25.81, 76.70, 26.21]
    },
    'Kanha National Park, India': {
      'coordinates': const LatLng(22.33, 80.63),
      'bbox': [80.43, 22.13, 80.83, 22.53]
    },
    'Bandipur National Park, India': {
      'coordinates': const LatLng(11.66, 76.63),
      'bbox': [76.43, 11.46, 76.83, 11.86]
    },
    'Kaziranga National Park, India': {
      'coordinates': const LatLng(26.66, 93.35),
      'bbox': [93.15, 26.46, 93.55, 26.86]
    },
    'Gir National Park, India': {
      'coordinates': const LatLng(21.16, 70.79),
      'bbox': [70.59, 20.96, 70.99, 21.36]
    },
    'Periyar Wildlife Sanctuary, India': {
      'coordinates': const LatLng(9.46, 77.14),
      'bbox': [76.94, 9.26, 77.34, 9.66]
    },
    'Western Ghats, India': {
      'coordinates': const LatLng(10.0, 77.0),
      'bbox': [76.8, 9.8, 77.2, 10.2]
    },
    'Borneo, Indonesia': {
      'coordinates': const LatLng(1.0, 114.0),
      'bbox': [113.8, 0.8, 114.2, 1.2]
    },
    'Kruger National Park, South Africa': {
      'coordinates': const LatLng(-23.98, 31.55),
      'bbox': [31.35, -24.18, 31.75, -23.78]
    },
    'Yellowstone National Park, USA': {
      'coordinates': const LatLng(44.42, -110.58),
      'bbox': [-110.78, 44.22, -110.38, 44.62]
    },
    'Galápagos Islands, Ecuador': {
      'coordinates': const LatLng(-0.95, -90.96),
      'bbox': [-91.16, -1.15, -90.76, -0.75]
    },
    'Daintree Rainforest, Australia': {
      'coordinates': const LatLng(-16.17, 145.42),
      'bbox': [145.22, -16.37, 145.62, -15.97]
    },
    'Valdivian Rainforest, Chile': {
      'coordinates': const LatLng(-39.88, -73.24),
      'bbox': [-73.44, -40.08, -73.04, -39.68]
    },
    'Kinabalu Park, Malaysia': {
      'coordinates': const LatLng(6.07, 116.54),
      'bbox': [116.34, 5.87, 116.74, 6.27]
    },
    'Sumatra, Indonesia': {
      'coordinates': const LatLng(0.58, 101.34),
      'bbox': [101.14, 0.38, 101.54, 0.78]
    },
    'New Guinea': {
      'coordinates': const LatLng(-5.5, 141.5),
      'bbox': [141.3, -5.7, 141.7, -5.3]
    },
    'Madagascar': {
      'coordinates': const LatLng(-18.9, 47.5),
      'bbox': [47.3, -19.1, 47.7, -18.7]
    },
  };

  Future<void> _runAnalysis(WatchlistItem item) async {
    setState(() {
      _isLoading = true;
      _detections.clear();
      _recentPeriod = null;
      _pastPeriod = null;
      _activeWatchlistItem = item;
    });

    try {
      final result = await _apiService.analyzeRegion(item.bbox);
      if (!mounted) return;

      setState(() {
        if (result['alerts'] != null) {
          final alerts = List<Map<String, dynamic>>.from(result['alerts']);
          _detections.addAll(alerts);
        }
        _recentPeriod = result['recentPeriod'];
        _pastPeriod = result['pastPeriod'];
        _lastSynced = DateTime.now();
      });

      _mapController.move(item.coordinates, 8.0);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Analysis complete for ${item.name}. Found ${_detections.length} alerts."),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('API Error: ${e.toString()}'),
        backgroundColor: Colors.red.shade700,
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Derive severity from the NDVI change value returned by the backend.
  String _getSeverityFromChange(double change) {
    if (change < -0.3) return 'critical';
    if (change < -0.15) return 'moderate';
    return 'low';
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade400;
      case 'moderate':
        return Colors.orange.shade400;
      default:
        return Colors.yellow.shade400;
    }
  }

  List<Marker> _buildDetectionMarkers() {
    return _detections.map((detection) {
      final lat = (detection['lat'] as num).toDouble();
      final lon = (detection['lon'] as num).toDouble();
      final change = (detection['change'] as num).toDouble();
      final severity = _getSeverityFromChange(change);
      final color = _getSeverityColor(severity);

      return Marker(
        width: 18.0,
        height: 18.0,
        point: LatLng(lat, lon),
        child: GestureDetector(
          onTap: () => _showDetectionDetailsDialog(detection),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverList(
            delegate: SliverChildListDelegate(
              [
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatsSummary(),
                      const SizedBox(height: 30),
                      Text("Global Deforestation Hotspots",
                          style: kSectionTitleStyle),
                      const SizedBox(height: 16),
                      _buildMapFilters(),
                      const SizedBox(height: 12),
                      MapPreview(
                        selectedLayer: _selectedMapFilter,
                        mapController: _mapController,
                        watchlistMarkers: _buildWatchlistMarkers(),
                        detectionMarkers: _buildDetectionMarkers(),
                        detectionPolygons: const [],
                        isSelectionMode: _isSelectionMode,
                        selectionPoints: _selectionPoints,
                        onMapTap: _onMapTapped,
                      ),
                      const SizedBox(height: 8),
                      if (_isSelectionMode) _buildSelectionControls(),
                      if (_recentPeriod != null) _buildAnalysisSummary(),
                      _buildLastSynced(),
                      const SizedBox(height: 30),
                      _buildWatchlist(),
                      const SizedBox(height: 30),
                      Text("Dashboard", style: kSectionTitleStyle),
                      const SizedBox(height: 16),
                      _buildDashboardList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () {
                final WatchlistItem? itemToRefresh = _activeWatchlistItem ??
                    (_watchlistRegions.isNotEmpty
                        ? _watchlistRegions.first
                        : null);
                if (itemToRefresh != null) {
                  _runAnalysis(itemToRefresh);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        "Add a region to your watchlist to run an analysis."),
                  ));
                }
              },
              backgroundColor: kAccentColor,
              tooltip: 'Refresh Analysis',
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: kBackgroundColor, strokeWidth: 2.0)
                  : const Icon(Icons.refresh, color: kBackgroundColor),
            ),
    );
  }

  Widget _buildAnalysisSummary() {
    final critical = _detections.where((d) => _getSeverityFromChange((d['change'] as num).toDouble()) == 'critical').length;
    final moderate = _detections.where((d) => _getSeverityFromChange((d['change'] as num).toDouble()) == 'moderate').length;

    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: NeuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Analysis Results",
                style: kSectionTitleStyle.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text("NDVI change detection between two periods.",
                style: kSecondaryBodyTextStyle),
            const SizedBox(height: 16),
            _buildDetailRow('Recent Period:', _recentPeriod ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow('Past Period:', _pastPeriod ?? 'N/A'),
            const SizedBox(height: 8),
            _buildDetailRow('Total Alerts:', '${_detections.length}'),
            const SizedBox(height: 8),
            _buildDetailRow('Critical:', '$critical', color: Colors.red.shade400),
            const SizedBox(height: 8),
            _buildDetailRow('Moderate:', '$moderate', color: Colors.orange.shade400),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250.0,
      backgroundColor: kBackgroundColor,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/satellite_forest.png',
              fit: BoxFit.cover,
            ).animate().fadeIn(duration: 500.ms),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, kBackgroundColor],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Real-time intelligence.",
                      style: kSectionTitleStyle.copyWith(fontSize: 30)),
                  Text("Zero trees lost.",
                      style: kSectionTitleStyle.copyWith(
                          color: kAccentColor, fontSize: 30)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(children: [
      Text(value, style: kStatValueStyle),
      const SizedBox(height: 4),
      Text(title, style: kSecondaryBodyTextStyle)
    ]);
  }

  Widget _buildStatsSummary() {
    return NeuCard(
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildStatItem("Active Alerts", _detections.length.toString()),
        _buildStatItem(
            "Regions Monitored", 22.toString()),
      ]),
    ).animate().slideY(delay: 200.ms, duration: 400.ms, curve: Curves.easeOut);
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      if (_selectionPoints.length >= 2) {
        _selectionPoints = [point];
      } else {
        _selectionPoints.add(point);
      }
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectionPoints = [];
      if (_isSelectionMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Selection Mode Enabled: Tap two corners on the map to define a region.'),
            backgroundColor: kAccentColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _runAnalysisOnSelection() {
    if (_selectionPoints.length < 2) return;

    final point1 = _selectionPoints[0];
    final point2 = _selectionPoints[1];

    final tempItem = WatchlistItem(
      name: "Custom Selection",
      coordinates: LatLng((point1.latitude + point2.latitude) / 2,
          (point1.longitude + point2.longitude) / 2),
      bbox: [
        min(point1.longitude, point2.longitude),
        min(point1.latitude, point2.latitude),
        max(point1.longitude, point2.longitude),
        max(point1.latitude, point2.latitude),
      ],
    );

    _runAnalysis(tempItem);
    setState(() {
      _isSelectionMode = false;
      _selectionPoints = [];
    });
  }

  void _addToWatchlist(String regionName) {
    if (_availableForestsData.containsKey(regionName) &&
        !_watchlistRegions.any((item) => item.name == regionName)) {
      final data = _availableForestsData[regionName]!;
      setState(() {
        final newItem = WatchlistItem(
            name: regionName,
            coordinates: data['coordinates'],
            bbox: data['bbox']);
        _watchlistRegions.add(newItem);
        _runAnalysis(newItem);
      });
    }
  }

  void _showDetectionDetailsDialog(Map<String, dynamic> detection) {
    final change = (detection['change'] as num).toDouble();
    final lat = (detection['lat'] as num).toStringAsFixed(4);
    final lon = (detection['lon'] as num).toStringAsFixed(4);
    final severity = _getSeverityFromChange(change);
    final Color severityColor = _getSeverityColor(severity);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kCardColor,
          title: Text('Detection Details',
              style: kSectionTitleStyle.copyWith(fontSize: 20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Severity:', severity.capitalize(),
                  color: severityColor),
              const SizedBox(height: 12),
              _buildDetailRow('NDVI Change:', change.toStringAsFixed(3)),
              const SizedBox(height: 12),
              _buildDetailRow('Coordinates:', '$lat, $lon'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Close',
                  style: TextStyle(
                      color: kAccentColor, fontWeight: FontWeight.bold)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: kSecondaryBodyTextStyle),
      const SizedBox(width: 8),
      Expanded(
          child: Text(value,
              style: kBodyTextStyle.copyWith(
                  fontWeight: FontWeight.bold, color: color ?? kWhiteColor))),
    ]);
  }

  Widget _buildSelectionControls() {
    bool canAnalyze = _selectionPoints.length == 2;
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: kAccentColor.withValues(alpha:0.5))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
            child: Text("Tap two corners to define an area.",
                style: kSecondaryBodyTextStyle)),
        const SizedBox(width: 12),
        TextButton(
            onPressed: _toggleSelectionMode,
            style: TextButton.styleFrom(foregroundColor: kWhiteColor),
            child: const Text("Cancel")),
        ElevatedButton.icon(
          onPressed: canAnalyze ? _runAnalysisOnSelection : null,
          icon: const Icon(Icons.analytics_outlined, size: 18),
          label: const Text("Analyze"),
          style: ElevatedButton.styleFrom(
              backgroundColor: kAccentColor,
              foregroundColor: kBackgroundColor,
              disabledBackgroundColor: Colors.grey.shade700),
        )
      ]),
    );
  }

  Widget _buildDashboardList() {
    return Column(children: [
      DashboardItem(
        icon: _isSelectionMode ? Icons.cancel_outlined : Icons.track_changes,
        title: "Analyze New Region",
        subtitle: _isSelectionMode
            ? "Selection mode is active"
            : "Select an area on the map",
        onTap: _toggleSelectionMode,
      ),
      const SizedBox(height: 12),
      DashboardItem(
        icon: Icons.notifications_active_outlined,
        title: "View All Alerts",
        subtitle: "Review deforestation events from last analysis",
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    AllAlertsScreen(detections: _detections))),
      ),

    ]);
  }

  List<Marker> _buildWatchlistMarkers() {
    return _watchlistRegions.map((item) {
      return Marker(
        width: 24.0,
        height: 24.0,
        point: item.coordinates,
        child: Container(
          decoration: BoxDecoration(
              color: kAccentColor.withValues(alpha:0.4),
              shape: BoxShape.circle,
              border: Border.all(color: kAccentColor, width: 2)),
          child: const Center(
              child: Icon(Icons.push_pin, color: kWhiteColor, size: 12)),
        ),
      );
    }).toList();
  }

  Widget _buildWatchlist() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("My Watchlist", style: kSectionTitleStyle),
        TextButton.icon(
            onPressed: _showAddWatchlistDialog,
            icon: const Icon(Icons.add, color: kAccentColor, size: 20),
            label: const Text('Add', style: TextStyle(color: kAccentColor))),
      ]),
      const SizedBox(height: 8),
      NeuCard(
        padding: EdgeInsets.zero,
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _watchlistRegions.length,
          itemBuilder: (context, index) {
            final item = _watchlistRegions[index];
            return ListTile(

              title: Text(item.name, style: kBodyTextStyle),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: kSecondaryTextColor, size: 16),
              onTap: () => _runAnalysis(item),
            );
          },
          separatorBuilder: (context, index) => const Divider(
              color: kBackgroundColor, height: 1, indent: 16, endIndent: 16),
        ),
      ),
    ]);
  }

  Widget _buildMapFilters() {
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: ['Heatmap', 'Satellite', 'Political'].map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(filter),
              selected: _selectedMapFilter == filter,
              onSelected: (selected) {
                if (selected) setState(() => _selectedMapFilter = filter);
              },
              backgroundColor: kCardColor,
              selectedColor: kAccentColor,
              labelStyle: TextStyle(
                  color: _selectedMapFilter == filter
                      ? kBackgroundColor
                      : kWhiteColor),
              checkmarkColor: kBackgroundColor,
            ),
          );
        }).toList()));
  }

  Widget _buildLastSynced() {
    final difference = DateTime.now().difference(_lastSynced);
    String timeAgo = (difference.inSeconds < 5)
        ? 'just now'
        : '${difference.inSeconds}s ago';
    if (difference.inMinutes >= 1) timeAgo = '${difference.inMinutes}m ago';
    if (difference.inHours >= 1) timeAgo = '${difference.inHours}h ago';
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text('Last updated: $timeAgo',
            style: kSecondaryBodyTextStyle.copyWith(fontSize: 12))
      ]),
    );
  }

  Future<void> _showAddWatchlistDialog() async {
    String? selectedForest;
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: kCardColor,
            title: Text('Add to Watchlist',
                style: kAppTitleStyle.copyWith(fontSize: 20)),
            content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
              return DropdownButton<String>(
                isExpanded: true,
                value: selectedForest,
                hint: Text('Select a forest to monitor',
                    style: kSecondaryBodyTextStyle),
                dropdownColor: kCardColor,
                style: kBodyTextStyle,
                icon: const Icon(Icons.arrow_drop_down, color: kAccentColor),
                underline: Container(height: 1, color: kAccentColor),
                items: _availableForestsData.keys
                    .where((forest) =>
                        !_watchlistRegions.any((item) => item.name == forest))
                    .map((String forest) => DropdownMenuItem<String>(
                        value: forest, child: Text(forest)))
                    .toList(),
                onChanged: (String? newValue) =>
                    setState(() => selectedForest = newValue),
              );
            }),
            actions: <Widget>[
              TextButton(
                  child: Text('Cancel', style: kSecondaryBodyTextStyle),
                  onPressed: () => Navigator.of(context).pop()),
              TextButton(
                  child: const Text('Add',
                      style: TextStyle(
                          color: kAccentColor, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (selectedForest != null) {
                      _addToWatchlist(selectedForest!);
                      Navigator.of(context).pop();
                    }
                  }),
            ],
          );
        });
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
class WatchlistItem {
  final String name;
  final LatLng coordinates;
  final List<double> bbox;  

  WatchlistItem({
    required this.name,
    required this.coordinates,
    required this.bbox,
  });
}
