import 'dart:io';
import 'package:lottie/lottie.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/pdf_report_service.dart';
import '../widgets/app_notification.dart';

class DiseaseInsightsScreen extends StatefulWidget {
  final File imageFile;
  final Map<String, dynamic> insights;

  const DiseaseInsightsScreen({
    super.key,
    required this.imageFile,
    required this.insights,
  });

  @override
  State<DiseaseInsightsScreen> createState() => _DiseaseInsightsScreenState();
}

class _DiseaseInsightsScreenState extends State<DiseaseInsightsScreen> {
  late PageController _pageCtrl;
  int _currentPage = 0;
  late List<_InsightPage> _pages;
  bool _sharingPdf = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _buildPages();
  }

  void _buildPages() {
    final i = widget.insights;
    _pages = [];

    _pages.add(_InsightPage(
      icon: Icons.medical_information_rounded,
      title: 'Overview',
      color: AppTheme.primary,
      child: _OverviewPage(
        imageFile: widget.imageFile,
        disease: i['disease']?.toString() ?? '--',
        diseaseConf: _asPercent(i['disease_confidence']),
        stage: i['stage']?.toString() ?? '--',
        stageConf: _asPercent(i['stage_confidence']),
        summary: i['summary']?.toString() ?? 'No summary available.',
      ),
    ));

    _pages.add(_InsightPage(
      icon: Icons.science_rounded,
      title: 'About & Causes',
      color: const Color(0xFF7B61FF),
      child: _TextPage(sections: [
        _Section(
          icon: Icons.help_outline_rounded,
          title: 'What is this condition?',
          text: i['definition']?.toString() ?? 'No definition available.',
          color: const Color(0xFF7B61FF),
        ),
        _Section(
          icon: Icons.psychology_outlined,
          title: 'Why does it happen?',
          text: i['causes']?.toString() ?? 'No information available.',
          color: AppTheme.warning,
        ),
      ]),
    ));

    final symptoms = _toList(i['symptoms']);
    if (symptoms.isNotEmpty) {
      _pages.add(_InsightPage(
        icon: Icons.sick_rounded,
        title: 'Symptoms',
        color: AppTheme.warning,
        child: _ListPage(
            items: symptoms,
            icon: Icons.circle,
            color: AppTheme.warning,
            emptyMessage: 'No symptoms listed.'),
      ));
    }

    final selfCare = _toList(i['self_care']);
    if (selfCare.isNotEmpty) {
      _pages.add(_InsightPage(
        icon: Icons.self_improvement_rounded,
        title: 'Self-Care',
        color: AppTheme.success,
        child: _ListPage(
            items: selfCare,
            icon: Icons.check_circle_outline_rounded,
            color: AppTheme.success,
            emptyMessage: 'No self-care tips.'),
      ));
    }

    final redFlags = _toList(i['red_flags']);
    if (redFlags.isNotEmpty) {
      _pages.add(_InsightPage(
        icon: Icons.warning_rounded,
        title: 'Red Flags',
        color: AppTheme.danger,
        child: _ListPage(
            items: redFlags,
            icon: Icons.warning_amber_rounded,
            color: AppTheme.danger,
            emptyMessage: 'No red flags listed.',
            highlighted: true),
      ));
    }

    final whenCare = _toList(i['when_to_seek_care']);
    final nextSteps = _toList(i['next_steps']);
    _pages.add(_InsightPage(
      icon: Icons.local_hospital_rounded,
      title: 'Next Steps',
      color: AppTheme.info,
      child: _FinalPage(
        whenToSeekCare: whenCare,
        nextSteps: nextSteps,
        onShareReport: _shareAsPdf,
        sharing: _sharingPdf,
      ),
    ));
  }

  String _asPercent(dynamic v) {
    if (v == null) return '--';
    if (v is num) return '${v.toStringAsFixed(1)}%';
    return v.toString();
  }

  List<String> _toList(dynamic v) {
    if (v == null) return [];
    if (v is List)
      return v
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    final s = v.toString().trim();
    return s.isEmpty ? [] : [s];
  }

  Future<void> _shareAsPdf() async {
    setState(() => _sharingPdf = true);
    try {
      await PdfReportService.shareReport(
        insights: widget.insights,
        imageFile: widget.imageFile,
      );
    } catch (e) {
      if (!mounted) return;
      AppNotification.error(context, 'Could not generate PDF. Try again.');
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
      _buildPages();
    }
  }

  void _goToPage(int page) {
    _pageCtrl.animateToPage(page,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _goHome() => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // ── Main content ──────────────────────────────────────────────
          Column(
            children: [
              // ── Gradient header ───────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Title row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          children: [
                            const SizedBox(width: 48),
                            const Expanded(
                              child: Text(
                                'Dermatology Insights',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentPage + 1}/${_pages.length}',
                                style: const TextStyle(
                                    fontFamily: 'Nunito',
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Step indicator
                      _StepIndicator(
                        total: _pages.length,
                        current: _currentPage,
                        pages: _pages,
                        onTap: _goToPage,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Page content ──────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() {
                    _currentPage = i;
                    _buildPages();
                  }),
                  itemBuilder: (_, i) => _pages[i].child,
                ),
              ),

              // ── Navigation buttons ────────────────────────────────────
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                    20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
                child: Row(
                  children: [
                    if (_currentPage > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _goToPage(_currentPage - 1),
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              size: 14),
                          label: const Text('Back'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: isLastPage
                          ? ElevatedButton.icon(
                              onPressed: _goHome,
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Done'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _goToPage(_currentPage + 1),
                              icon: const Text('Next'),
                              label: const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14),
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── PDF generation overlay (floats over everything) ───────────
          if (_sharingPdf)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Lottie.asset('assets/lottie/loader.json'),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Generating PDF Report...',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'This may take a few seconds',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: AppTheme.textLight,
                        ),
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
}

// ── Step Indicator ────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int total, current;
  final List<_InsightPage> pages;
  final void Function(int) onTap;

  const _StepIndicator(
      {required this.total,
      required this.current,
      required this.pages,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: total,
        itemBuilder: (_, i) {
          final active = i == current;
          final done = i < current;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? pages[i].color
                    : done
                        ? pages[i].color.withOpacity(0.15)
                        : Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (active || done)
                      ? pages[i].color
                      : Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  done ? Icons.check_rounded : pages[i].icon,
                  size: 13,
                  color: active
                      ? Colors.white
                      : done
                          ? pages[i].color
                          : Colors.white70,
                ),
                if (active) ...[
                  const SizedBox(width: 5),
                  Text(pages[i].title,
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────
class _InsightPage {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  const _InsightPage(
      {required this.icon,
      required this.title,
      required this.color,
      required this.child});
}

class _Section {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  const _Section(
      {required this.icon,
      required this.title,
      required this.text,
      required this.color});
}

// ── Page widgets ──────────────────────────────────────────────────────────────
class _OverviewPage extends StatelessWidget {
  final File imageFile;
  final String disease, diseaseConf, stage, stageConf, summary;

  const _OverviewPage(
      {required this.imageFile,
      required this.disease,
      required this.diseaseConf,
      required this.stage,
      required this.stageConf,
      required this.summary});

  Color _stageColor(String s) {
    switch (s.toLowerCase()) {
      case 'mild':
        return AppTheme.success;
      case 'moderate':
        return AppTheme.warning;
      case 'severe':
        return AppTheme.danger;
      default:
        return AppTheme.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _stageColor(stage);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(imageFile,
              height: 180, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
          ),
          child: Column(children: [
            _row(Icons.medical_services_rounded, 'Detected Condition', disease,
                diseaseConf, AppTheme.primary),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _row(Icons.bar_chart_rounded, 'Severity Stage', stage, stageConf,
                color),
          ]),
        ),
        const SizedBox(height: 14),
        _textCard(
            'Summary', summary, Icons.summarize_rounded, AppTheme.primary),
      ]),
    );
  }

  Widget _row(
      IconData icon, String label, String value, String conf, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 24),
      ),
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
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(conf,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 13)),
      ),
    ]);
  }
}

class _TextPage extends StatelessWidget {
  final List<_Section> sections;
  const _TextPage({required this.sections});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: sections
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _textCard(s.title, s.text, s.icon, s.color),
                ))
            .toList(),
      ),
    );
  }
}

class _ListPage extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;
  final String emptyMessage;
  final bool highlighted;

  const _ListPage(
      {required this.items,
      required this.icon,
      required this.color,
      required this.emptyMessage,
      this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: items.isEmpty
            ? [
                Text(emptyMessage,
                    style: const TextStyle(color: AppTheme.textLight))
              ]
            : items
                .asMap()
                .entries
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: highlighted
                              ? color.withOpacity(0.06)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: highlighted
                                  ? color.withOpacity(0.2)
                                  : Colors.grey.shade100),
                          boxShadow: highlighted
                              ? []
                              : [
                                  BoxShadow(
                                      color: Colors.grey.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2))
                                ],
                        ),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    shape: BoxShape.circle),
                                child: Icon(icon, size: 13, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(e.value,
                                      style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 14,
                                          height: 1.5,
                                          color: highlighted
                                              ? AppTheme.danger
                                              : AppTheme.textDark))),
                            ]),
                      ),
                    ))
                .toList(),
      ),
    );
  }
}

class _FinalPage extends StatelessWidget {
  final List<String> whenToSeekCare;
  final List<String> nextSteps;
  final VoidCallback onShareReport;
  final bool sharing;

  const _FinalPage(
      {required this.whenToSeekCare,
      required this.nextSteps,
      required this.onShareReport,
      required this.sharing});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(children: [
        if (whenToSeekCare.isNotEmpty) ...[
          _sectionHeader(
              'When to Seek Care', Icons.local_hospital_rounded, AppTheme.info),
          const SizedBox(height: 10),
          ...whenToSeekCare.map((e) => _item(e, AppTheme.info)),
          const SizedBox(height: 20),
        ],
        if (nextSteps.isNotEmpty) ...[
          _sectionHeader('Recommended Next Steps', Icons.checklist_rounded,
              AppTheme.success),
          const SizedBox(height: 10),
          ...nextSteps.map((e) => _item(e, AppTheme.success)),
          const SizedBox(height: 24),
        ],

        // PDF share card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primary.withOpacity(0.9),
              AppTheme.accent.withOpacity(0.9),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 10),
            const Text('Download PDF Report',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            const SizedBox(height: 4),
            const Text(
              'Generate a branded PDF with your full analysis\nto share with your dermatologist',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: Colors.white70,
                  height: 1.4),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sharing ? null : onShareReport,
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: const Text('Share PDF Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  disabledBackgroundColor: Colors.white70,
                  disabledForegroundColor: AppTheme.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 10),
      Text(title,
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color)),
    ]);
  }

  Widget _item(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            margin: const EdgeInsets.only(top: 6),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.textDark))),
      ]),
    );
  }
}

// ── Shared card helper ────────────────────────────────────────────────────────
Widget _textCard(String title, String text, IconData icon, Color color) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 4))
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color)),
      ]),
      const SizedBox(height: 10),
      Text(text,
          style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              height: 1.6,
              color: AppTheme.textDark)),
    ]),
  );
}
