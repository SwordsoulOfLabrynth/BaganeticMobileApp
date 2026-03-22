import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/utils/auth_gate.dart';
import '../../core/utils/helpers.dart';
import '../../data/models/pagoda_model.dart';
import '../../data/models/road_report_model.dart';
import '../providers/auth_provider.dart';
import '../providers/road_report_provider.dart';

class PagodaRoadReportsSection extends StatelessWidget {
  const PagodaRoadReportsSection({super.key, required this.pagoda});

  final Pagoda pagoda;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoadReportProvider()..loadReports(pagoda.id),
      child: _PagodaRoadReportsBody(pagoda: pagoda),
    );
  }
}

class _PagodaRoadReportsBody extends StatefulWidget {
  const _PagodaRoadReportsBody({required this.pagoda});

  final Pagoda pagoda;

  @override
  State<_PagodaRoadReportsBody> createState() => _PagodaRoadReportsBodyState();
}

class _PagodaRoadReportsBodyState extends State<_PagodaRoadReportsBody> {
  final TextEditingController _noteController = TextEditingController();
  String _category = 'unsafe_lane';
  String _severity = 'medium';
  bool _isComposerVisible = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<RoadReportProvider>();
    final auth = context.watch<AuthProvider>();
    final isSignedIn = auth.user != null;
    final currentUserId = auth.user?.uid ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('roadReport.title'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  if (!isSignedIn) {
                    await AuthGate.openSignIn(context);
                    return;
                  }
                  setState(() {
                    _isComposerVisible = true;
                  });
                },
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(l10n.translate('roadReport.write')),
              ),
            ),
            if (!isSignedIn)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.translate('roadReport.signInPrompt'),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ),
            if (_isComposerVisible && isSignedIn) ...[
              const SizedBox(height: 12),
              _buildComposer(context, currentUserId),
            ],
            const SizedBox(height: 8),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.reports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(l10n.translate('roadReport.empty')),
              )
            else
              Column(
                children: provider.reports
                    .map((report) {
                      final canDelete = currentUserId == report.reporterUserId;
                      return _buildReportTile(
                        context,
                        provider: provider,
                        report: report,
                        canDelete: canDelete,
                      );
                    })
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context, String userId) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: InputDecoration(
            labelText: l10n.translate('roadReport.categoryLabel'),
          ),
          items: [
            DropdownMenuItem(
              value: 'unsafe_lane',
              child: Text(l10n.translate('roadReport.category.unsafeLane')),
            ),
            DropdownMenuItem(
              value: 'poor_surface',
              child: Text(l10n.translate('roadReport.category.poorSurface')),
            ),
            DropdownMenuItem(
              value: 'blocked_access',
              child: Text(l10n.translate('roadReport.category.blockedAccess')),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _category = value;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _severity,
          decoration: InputDecoration(
            labelText: l10n.translate('roadReport.severityLabel'),
          ),
          items: [
            DropdownMenuItem(
              value: 'low',
              child: Text(l10n.translate('roadReport.severity.low')),
            ),
            DropdownMenuItem(
              value: 'medium',
              child: Text(l10n.translate('roadReport.severity.medium')),
            ),
            DropdownMenuItem(
              value: 'high',
              child: Text(l10n.translate('roadReport.severity.high')),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _severity = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.translate('roadReport.noteHint'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _isComposerVisible = false;
                        _noteController.clear();
                        _category = 'unsafe_lane';
                        _severity = 'medium';
                      });
                    },
              child: Text(l10n.translate('common.cancel')),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () => _submitReport(context, userId),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.translate('roadReport.submit')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportTile(
    BuildContext context, {
    required RoadReportProvider provider,
    required RoadReport report,
    required bool canDelete,
  }) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(_categoryLabel(l10n, report.category)),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      label: Text(_severityLabel(l10n, report.severity)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final successMessage = l10n.translate(
                      'roadReport.deleteSuccess',
                    );
                    await provider.deleteReport(report.id);
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(successMessage)),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.translate('common.delete'),
                ),
            ],
          ),
          Text(report.note),
          const SizedBox(height: 6),
          Text(
            l10n.translate(
              'roadReport.expiresOn',
              args: {'date': Helpers.formatDate(report.expiresAt)},
            ),
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(BuildContext context, String userId) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<RoadReportProvider>();
    final successMessage = l10n.translate('roadReport.submitSuccess');
    final errorMessage = l10n.translate('roadReport.submitError');
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      Helpers.showSnackBar(
        context,
        l10n.translate('roadReport.noteRequired'),
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final now = DateTime.now();
    final report = RoadReport(
      id: const Uuid().v4(),
      pagodaId: widget.pagoda.id,
      pagodaName: widget.pagoda.name,
      reporterUserId: userId,
      category: _category,
      severity: _severity,
      note: note,
      status: RoadReport.statusActive,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );

    try {
      await provider.submitReport(report);
      if (!mounted) return;
      setState(() {
        _isComposerVisible = false;
        _isSubmitting = false;
        _noteController.clear();
        _category = 'unsafe_lane';
        _severity = 'medium';
      });
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      messenger.showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  String _categoryLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'poor_surface':
        return l10n.translate('roadReport.category.poorSurface');
      case 'blocked_access':
        return l10n.translate('roadReport.category.blockedAccess');
      case 'unsafe_lane':
      default:
        return l10n.translate('roadReport.category.unsafeLane');
    }
  }

  String _severityLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'low':
        return l10n.translate('roadReport.severity.low');
      case 'high':
        return l10n.translate('roadReport.severity.high');
      case 'medium':
      default:
        return l10n.translate('roadReport.severity.medium');
    }
  }
}
