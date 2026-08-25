import 'package:carboneye/constants.dart';
import 'package:carboneye/widgets/neu_card.dart';
import 'package:flutter/material.dart';

class AllAlertsScreen extends StatelessWidget {
  final List<Map<String, dynamic>> detections;

  const AllAlertsScreen({super.key, required this.detections});

  String _getSeverity(double change) {
    if (change < -0.3) return 'CRITICAL';
    if (change < -0.15) return 'MODERATE';
    return 'LOW';
  }

  Color _getSeverityColor(double change) {
    if (change < -0.3) return Colors.red.shade400;
    if (change < -0.15) return Colors.orange.shade400;
    return Colors.yellow.shade400;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: Text("All Alerts (${detections.length})", style: kAppTitleStyle),
        backgroundColor: kBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: kWhiteColor),
      ),
      body: detections.isEmpty
          ? Center(
              child: Text(
                "No alerts to display.",
                style: kSecondaryBodyTextStyle,
              ),
            )
          : ListView.builder(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              itemCount: detections.length,
              itemBuilder: (context, index) {
                final alert = detections[index];
                final change = (alert['change'] as num).toDouble();
                final lat = (alert['lat'] as num).toStringAsFixed(4);
                final lon = (alert['lon'] as num).toStringAsFixed(4);
                final severity = _getSeverity(change);
                final color = _getSeverityColor(change);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: NeuCard(
                    child: ListTile(
                      leading: Icon(Icons.warning_amber_rounded, color: color),
                      title: Text(
                        'Alert #${index + 1}: $severity',
                        style: kBodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'NDVI Change: ${change.toStringAsFixed(3)}  •  ($lat, $lon)',
                        style: kSecondaryBodyTextStyle,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
