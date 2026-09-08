import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';
import '../widgets/app_notification.dart';
import 'profile_screen.dart';
import 'disease_insights_screen.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? image;
  bool isLoading = false;

  String disease = '--';
  String diseaseConfidence = '--';
  String severity = '--';
  String severityConfidence = '--';

  Map<String, dynamic>? latestPrediction;
  Map<String, dynamic>? readyInsights;
  bool _isNormal = false;

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final file = File(picked.path);
      if (!await file.exists()) throw Exception('File not found');
      setState(() {
        image = file;
        disease = '--';
        diseaseConfidence = '--';
        severity = '--';
        severityConfidence = '--';
        latestPrediction = null;
        readyInsights = null;
        _isNormal = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, 'Unable to load image. Try again.');
    }
  }

  Future<void> runDetection() async {
    if (image == null) return;
    setState(() => isLoading = true);
    try {
      final result = await ApiService.analyzeImage(image!);
      final diseaseCode = result['disease_code']?.toString() ?? '';
      final isNormal = diseaseCode == 'NORMAL';

      setState(() {
        latestPrediction = result;
        _isNormal = isNormal;
        // Only store insights for non-normal detections
        readyInsights =
            isNormal ? null : result['insights'] as Map<String, dynamic>?;
        disease = result['disease']?.toString() ?? '--';
        diseaseConfidence =
            '${(result['disease_confidence'] as num?)?.toStringAsFixed(1) ?? '--'}%';
        // Show "Healthy" for normal skin, actual stage otherwise
        severity = isNormal ? 'Healthy' : (result['stage']?.toString() ?? '--');
        severityConfidence = isNormal
            ? ''
            : '${(result['stage_confidence'] as num?)?.toStringAsFixed(1) ?? '--'}%';
      });
      if (!mounted) return;
      AppNotification.success(context, 'Detection complete!');
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, 'Detection failed. Please try again.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void openInsights() {
    if (image == null || readyInsights == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiseaseInsightsScreen(
          imageFile: image!,
          insights: readyInsights!,
        ),
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case 'mild':
        return AppTheme.success;
      case 'moderate':
        return AppTheme.warning;
      case 'severe':
        return AppTheme.danger;
      case 'healthy':
        return AppTheme.success;
      default:
        return AppTheme.textLight;
    }
  }

  bool get _hasResult => disease != '--' && latestPrediction != null;
  bool get _hasInsights => !_isNormal && readyInsights != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('SkinVision AI',
                                style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text('AI-powered skin analysis',
                                style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 12,
                                    color: Colors.white70)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white70, width: 2),
                          ),
                          child: const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.person_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      children: [
                        // Image preview card
                        Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withOpacity(0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: image == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color:
                                            AppTheme.primary.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 40,
                                          color: AppTheme.primary),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text('Upload skin image',
                                        style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textMid)),
                                    const SizedBox(height: 4),
                                    const Text('JPG, PNG supported',
                                        style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 12,
                                            color: AppTheme.textLight)),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(image!,
                                      fit: BoxFit.cover,
                                      width: double.infinity),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                                child: _actionButton(
                                    icon: Icons.photo_library_rounded,
                                    label: 'Choose Image',
                                    onTap: isLoading ? null : pickImage,
                                    outlined: true)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _actionButton(
                                    icon: Icons.biotech_rounded,
                                    label: 'Analyze',
                                    onTap: (image == null || isLoading)
                                        ? null
                                        : runDetection)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Results card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: const Icon(Icons.analytics_rounded,
                                      color: AppTheme.primary, size: 20),
                                ),
                                const SizedBox(width: 10),
                                const Text('Detection Results',
                                    style: TextStyle(
                                        fontFamily: 'Nunito',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.textDark)),
                              ]),
                              const SizedBox(height: 16),
                              _resultRow(
                                  'Detected Condition',
                                  disease,
                                  diseaseConfidence != '--'
                                      ? diseaseConfidence
                                      : null,
                                  AppTheme.primary),
                              const SizedBox(height: 12),
                              _resultRow(
                                  'Severity Stage',
                                  severity,
                                  severityConfidence.isNotEmpty
                                      ? severityConfidence
                                      : null,
                                  _severityColor(severity)),
                            ],
                          ),
                        ),

                        // ── View Insights button (hidden for normal skin) ──
                        if (_hasInsights) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: openInsights,
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 18),
                              label: const Text('View Insights & Guidance'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],

                        // ── Healthy skin message (shown only for normal) ──
                        if (_hasResult && _isNormal) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppTheme.success.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppTheme.success, size: 28),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Skin appears healthy!',
                                          style: TextStyle(
                                              fontFamily: 'Nunito',
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.success)),
                                      SizedBox(height: 2),
                                      Text(
                                        'No skin condition detected. Keep up with regular skin checks and sun protection.',
                                        style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 12,
                                            color: AppTheme.textMid,
                                            height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Disclaimer
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.info.withOpacity(0.2)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppTheme.info, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                                child: Text(
                              'Results are for educational purposes only. Always consult a dermatologist.',
                              style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  color: AppTheme.info,
                                  height: 1.4),
                            )),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                          width: 80,
                          child: Lottie.asset('assets/lottie/loader.json')),
                      const SizedBox(height: 12),
                      const Text('Analyzing image...',
                          style: TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(
      {required IconData icon,
      required String label,
      VoidCallback? onTap,
      bool outlined = false}) {
    if (outlined) {
      return SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ));
    }
    return SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ));
  }

  Widget _resultRow(
      String label, String value, String? confidence, Color color) {
    return Row(children: [
      Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 12),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 12, color: AppTheme.textLight)),
        Text(value,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color)),
      ])),
      if (confidence != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(confidence,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ),
    ]);
  }
}
