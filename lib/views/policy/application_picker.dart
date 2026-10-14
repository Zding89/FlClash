import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/applications.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

class PolicyApplicationPicker extends StatefulWidget {
  const PolicyApplicationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.catalog,
  });
  final PolicyMatch value;
  final ValueChanged<PolicyMatch> onChanged;
  final PolicyApplicationCatalog? catalog;
  @override
  State<PolicyApplicationPicker> createState() =>
      _PolicyApplicationPickerState();
}

class _PolicyApplicationPickerState extends State<PolicyApplicationPicker> {
  List<PolicyApplication> _applications = [];
  bool _loading = true;
  bool _failed = false;
  bool _unsupported = false;
  String _query = '';
  int _epoch = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final applications = await (widget.catalog ?? PolicyApplicationCatalog())
          .load();
      if (mounted && epoch == _epoch) {
        setState(() => _applications = applications);
      }
    } on UnsupportedError {
      if (mounted && epoch == _epoch) {
        setState(() {
          _failed = true;
          _unsupported = true;
        });
      }
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  List<PolicyMatch> get _selected => widget.value.type == PolicyMatchType.any
      ? widget.value.children
      : widget.value.values.isEmpty
      ? []
      : [widget.value];
  bool _contains(PolicyApplication app) => _selected.any(
    (match) =>
        match.values.contains(app.processPathPattern) ||
        match.values.contains(app.executable),
  );
  void _change(PolicyApplication application, bool selected) {
    final matches = <PolicyMatch>[];
    for (final match in _selected) {
      final values = match.values
          .where(
            (v) =>
                v != application.processPathPattern &&
                v != application.executable,
          )
          .toList();
      if (values.isNotEmpty) {
        matches.add(PolicyMatch(type: match.type, values: values));
      }
    }
    if (selected) {
      matches.add(
        PolicyMatch(
          type: PolicyMatchType.processPathRegex,
          values: [application.processPathPattern],
        ),
      );
    }
    widget.onChanged(
      matches.length > 1
          ? PolicyMatch(type: PolicyMatchType.any, children: matches)
          : matches.firstOrNull ??
                const PolicyMatch(type: PolicyMatchType.processPathRegex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(strings.policyInstalledApps)),
            IconButton(
              tooltip: strings.update,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        Text(
          strings.policyAppsHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_loading) ...[
          const LinearProgressIndicator(),
          Text(strings.policyAppsLoading),
        ] else if (_failed)
          Text(
            _unsupported
                ? strings.policyAppsUnsupported
                : strings.policyAppsFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        TextField(
          decoration: InputDecoration(
            labelText: strings.search,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _query = value.toLowerCase()),
        ),
        if (!_loading && !_failed)
          SizedBox(
            height: 240,
            child: ListView(
              children: [
                for (final application in _applications.where(
                  (app) =>
                      '${app.label} ${app.path}'.toLowerCase().contains(_query),
                ))
                  CheckboxListTile(
                    value: _contains(application),
                    title: Text(application.label),
                    subtitle: Text(
                      application.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (value) => _change(application, value == true),
                  ),
                if (_applications.isEmpty)
                  Text(strings.nullTip(strings.policyInstalledApps)),
              ],
            ),
          ),
        for (final match in _selected)
          for (final value in match.values)
            if (!_applications.any(
              (app) =>
                  value == app.processPathPattern || value == app.executable,
            ))
              InputChip(
                label: Text(
                  policyApplicationLabel(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: () {
                  final matches = [
                    for (final entry in _selected)
                      if (entry.values.any((v) => v != value))
                        PolicyMatch(
                          type: entry.type,
                          values: entry.values
                              .where((v) => v != value)
                              .toList(),
                        ),
                  ];
                  widget.onChanged(
                    matches.length > 1
                        ? PolicyMatch(
                            type: PolicyMatchType.any,
                            children: matches,
                          )
                        : matches.firstOrNull ??
                              const PolicyMatch(
                                type: PolicyMatchType.processPathRegex,
                              ),
                  );
                },
              ),
      ],
    );
  }
}
