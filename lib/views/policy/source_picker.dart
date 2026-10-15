import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/database.dart';
import 'package:fl_clash/models/profile.dart';
import 'package:fl_clash/views/profiles/add.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PolicySourcePicker extends ConsumerStatefulWidget {
  const PolicySourcePicker({
    super.key,
    required this.selected,
    required this.onSave,
  });

  final List<int> selected;
  final Future<void> Function(List<int>) onSave;

  @override
  ConsumerState<PolicySourcePicker> createState() => _PolicySourcePickerState();
}

class _PolicySourcePickerState extends ConsumerState<PolicySourcePicker> {
  late final List<int> _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected.toSet().toList();
  }

  Future<void> _save() async {
    if (_saving) return;
    final strings = context.appLocalizations;
    if (_selected.length > 20) {
      setState(() => _error = strings.policyLocalSourceLimit);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(List.unmodifiable(_selected));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = strings.policyOperationFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    await showExtend<void>(
      context,
      builder: (context) => AdaptiveSheetScaffold(
        title: context.appLocalizations.addProfile,
        body: AddProfileView(context: context, navigateToProfiles: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.appLocalizations;
    final profiles = ref.watch(profilesProvider);
    final options = {
      for (final profile in profiles) profile.id: profile.realLabel,
      for (final id in _selected)
        if (!profiles.any((profile) => profile.id == id))
          id: strings.policySourceMissing,
    };
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(strings.policySubscriptionSources),
        content: SizedBox(
          width: 520,
          height: (MediaQuery.sizeOf(context).height * .48).clamp(160.0, 420.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saving) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              Expanded(
                child: options.isEmpty
                    ? Center(child: Text(strings.policyLocalNoSubscriptions))
                    : ListView(
                        children: [
                          for (final entry in options.entries)
                            CheckboxListTile(
                              key: ValueKey('policy-source-${entry.key}'),
                              contentPadding: EdgeInsets.zero,
                              title: Text(entry.value),
                              value: _selected.contains(entry.key),
                              onChanged: _saving
                                  ? null
                                  : (checked) => setState(() {
                                      if (checked == true) {
                                        _selected.add(entry.key);
                                      } else {
                                        _selected.remove(entry.key);
                                      }
                                      _error = null;
                                    }),
                            ),
                        ],
                      ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _add,
                  icon: const Icon(Icons.add),
                  label: Text(strings.policyAddSubscription),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
