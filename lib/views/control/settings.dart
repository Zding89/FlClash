import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/control/password.dart';
import 'package:fl_clash/control/service.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class LocalControlSettings extends StatefulWidget {
  const LocalControlSettings({super.key, required this.service});

  final LocalControlService service;

  @override
  State<LocalControlSettings> createState() => _LocalControlSettingsState();
}

class _LocalControlSettingsState extends State<LocalControlSettings> {
  bool _revealed = false;

  String get _toolPath => p.normalize(
    p.join(
      p.dirname(Platform.resolvedExecutable),
      '..',
      'Resources',
      'control',
      'flclashctl',
    ),
  );

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.appLocalizations.copySuccess)),
    );
  }

  Future<void> _editPassword({bool random = false}) async {
    final l10n = context.appLocalizations;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordDialog(random: random),
    );
    if (password == null || !mounted) return;
    final saved = await widget.service.rotatePassword(password);
    if (!mounted) return;
    setState(() => _revealed = false);
    if (!saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.localControlSaveFailed)));
    }
  }

  Future<void> _showCommands() => showDialog<void>(
    context: context,
    builder: (context) => CommonDialog(
      title: context.appLocalizations.localControlCommands,
      child: const SelectableText(
        'flclashctl status\nflclashctl capabilities\nflclashctl start\nflclashctl stop\nflclashctl restart\nflclashctl invoke <command> [JSON]\nflclashctl --password-stdin invoke <command> [JSON]\nflclashctl --password-fd <fd> invoke <command> [JSON]\nflclashctl --idempotency-key <key> invoke <command> [JSON]\nflclashctl invoke operation_query {"operationId":"..."}',
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final service = widget.service;
        final password = service.revealPassword();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.localControlTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Text(l10n.localControlDescription),
                      value: service.enabled,
                      onChanged: service.busy || !service.supported
                          ? null
                          : (enabled) async {
                              if (enabled) {
                                await service.enable();
                              } else {
                                await service.disable();
                              }
                            },
                    ),
                    Text(
                      service.errorCode != null || !service.supported
                          ? l10n.localControlUnavailable
                          : service.enabled
                          ? l10n.localControlReady
                          : l10n.localControlDisabled,
                      style: TextStyle(
                        color: service.errorCode != null
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (service.busy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.localControlPassword,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        password == null
                            ? '—'
                            : _revealed
                            ? password
                            : '••••••••••••••••••••',
                        style: const TextStyle(fontFamily: 'JetBrainsMono'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: password == null || service.busy
                              ? null
                              : () => setState(() => _revealed = !_revealed),
                          icon: Icon(
                            _revealed
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          label: Text(l10n.show),
                        ),
                        OutlinedButton.icon(
                          onPressed: password == null || service.busy
                              ? null
                              : () => _copy(password),
                          icon: const Icon(Icons.copy_outlined),
                          label: Text(l10n.copy),
                        ),
                        OutlinedButton.icon(
                          onPressed: password == null || service.busy
                              ? null
                              : _editPassword,
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(l10n.localControlChangePassword),
                        ),
                        OutlinedButton.icon(
                          onPressed: password == null || service.busy
                              ? null
                              : () => _editPassword(random: true),
                          icon: const Icon(Icons.casino_outlined),
                          label: Text(l10n.localControlRandomPassword),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.localControlPasswordHint),
                    const Divider(height: 36),
                    Text(
                      l10n.localControlUsage,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.localControlUsageHint),
                    const SizedBox(height: 12),
                    const SelectableText(
                      r'$ flclashctl status',
                      style: TextStyle(fontFamily: 'JetBrainsMono'),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _copy(_toolPath),
                          icon: const Icon(Icons.copy),
                          label: Text(l10n.localControlCopyPath),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showCommands,
                          icon: const Icon(Icons.terminal),
                          label: Text(l10n.localControlCommands),
                        ),
                      ],
                    ),
                    const Divider(height: 36),
                    Text(
                      l10n.localControlSecurity,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.localControlSecurityHint),
                    const SizedBox(height: 12),
                    Text(l10n.localControlExitHint),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.random});
  final bool random;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  late final _controller = TextEditingController(
    text: widget.random ? generateControlPassword() : '',
  );
  final _form = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.appLocalizations;
    return CommonDialog(
      title: widget.random
          ? l10n.localControlRandomPassword
          : l10n.localControlChangePassword,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text);
            }
          },
          child: Text(l10n.save),
        ),
      ],
      child: Form(
        key: _form,
        child: TextFormField(
          controller: _controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          validator: (value) => isValidControlPassword(value ?? '')
              ? null
              : l10n.localControlPasswordValidation,
          decoration: InputDecoration(
            labelText: l10n.localControlPassword,
            helperText: l10n.localControlPasswordValidation,
            helperMaxLines: 3,
          ),
        ),
      ),
    );
  }
}
