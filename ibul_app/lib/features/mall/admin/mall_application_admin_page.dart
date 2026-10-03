import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../models/mall_application.dart';
import 'mall_admin_repository.dart';
import 'mall_application_admin_detail.dart';
import 'mall_publication_admin_section.dart';

class MallApplicationAdminPage extends StatefulWidget {
  const MallApplicationAdminPage({super.key, this.repository});

  final MallAdminRepository? repository;

  @override
  State<MallApplicationAdminPage> createState() =>
      _MallApplicationAdminPageState();
}

class _MallApplicationAdminPageState extends State<MallApplicationAdminPage> {
  late final MallAdminRepository _repository =
      widget.repository ?? MallAdminRepository();

  static const _filters = <String?, String>{
    null: 'Tümü',
    'pending_review': 'Bekleyen',
    'needs_info': 'Bilgi İstendi',
    'approved': 'Onaylanan',
    'rejected': 'Reddedilen',
  };

  MallAdminQueueCounts? _counts;
  List<MallApplication> _items = [];
  String? _status;
  String _search = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repository.counts(),
        _repository.getApplications(status: _status, search: _search),
      ]);
      if (!mounted) return;
      setState(() {
        _counts = results[0] as MallAdminQueueCounts;
        _items = results[1] as List<MallApplication>;
      });
    } catch (error) {
      debugPrint('[mall-admin] list $error');
      if (!mounted) return;
      setState(() => _error = mallAdminErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MallApplication application) async {
    await showDialog<void>(
      context: context,
      builder: (context) => MallApplicationAdminDetail(
        application: application,
        repository: _repository,
        onChanged: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AVM Başvuruları',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (_counts != null) _kpis(_counts!),
          const SizedBox(height: 12),
          MallPublicationAdminSection(repository: _repository),
          TextField(
            decoration: const InputDecoration(
              hintText: 'AVM, şehir, ilçe veya yetkili ara',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              _search = value;
              _load();
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _filters.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _status == entry.key,
                  onSelected: (_) {
                    setState(() => _status = entry.key);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _kpis(MallAdminQueueCounts counts) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpi('Bekleyen', counts.pending),
        _kpi('Bilgi Bekleyen', counts.needsInfo),
        _kpi('Onaylanan', counts.approved),
        _kpi('Reddedilen', counts.rejected),
      ],
    );
  }

  Widget _kpi(String label, int value) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey)),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Yeniden dene')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      final empty = _status == null || _status == 'pending_review'
          ? 'Bekleyen AVM başvurusu bulunmuyor.'
          : 'Bu filtrede başvuru bulunmuyor.';
      return Center(child: Text(empty));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _row(_items[index]),
    );
  }

  Widget _row(MallApplication application) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final location = '${application.district} / ${application.city}';
    final person =
        '${application.authorizedPersonName} — ${application.authorizedPersonTitle}';
    final date = application.submittedAt ?? application.createdAt;
    final children = <Widget>[
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              application.mallName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(location),
            Text(person),
            if (date != null) Text(_format(date)),
          ],
        ),
      ),
      Chip(label: Text(mallAdminStatusLabel(application.status))),
      TextButton(onPressed: () => _open(application), child: const Text('İncele')),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(children: children)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    application.mallName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(location),
                  Text(person),
                  if (date != null) Text(_format(date)),
                  const SizedBox(height: 8),
                  Chip(label: Text(mallAdminStatusLabel(application.status))),
                  TextButton(
                    onPressed: () => _open(application),
                    child: const Text('İncele'),
                  ),
                ],
              ),
      ),
    );
  }

  String _format(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }
}
