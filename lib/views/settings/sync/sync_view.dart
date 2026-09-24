import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:storypad/views/settings/sync/sync_view_model.dart';
import 'package:storypad/widgets/base_view/base_route.dart';
import 'package:storypad/widgets/sp_icons.dart';
import 'package:storypad/widgets/sp_section_title.dart';

/// Opt-in, end-to-end-encrypted sync settings (Gap #12, ADR-009).
///
/// The user provides their own WebDAV/Nextcloud server plus a passphrase;
/// backup archives are encrypted client-side before upload, so the server
/// only ever stores ciphertext. Off by default.
class SyncRoute extends BaseRoute {
  const SyncRoute();

  @override
  Widget buildPage(BuildContext context) => const SyncView();
}

class SyncView extends StatelessWidget {
  const SyncView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SyncViewModel>(
      create: (context) => SyncViewModel(),
      child: const _SyncContent(),
    );
  }
}

class _SyncContent extends StatelessWidget {
  const _SyncContent();

  @override
  Widget build(BuildContext context) {
    final SyncViewModel viewModel = context.watch<SyncViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(tr("page.sync.title"))),
      body: ListView(
        children: [
          SpSectionTitle(title: tr("page.sync.server_section")),
          SwitchListTile(
            secondary: const Icon(SpIcons.nextcloud),
            title: Text(tr("page.sync.enable_title")),
            subtitle: Text(tr("page.sync.enable_subtitle")),
            value: viewModel.enabled,
            onChanged: viewModel.setEnabled,
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(tr("page.sync.server_url")),
            subtitle: Text(
              viewModel.serverUrlController.text.isEmpty
                  ? tr("page.sync.not_configured")
                  : viewModel.serverUrlController.text,
            ),
            onTap: () => _showServerSheet(context, viewModel),
          ),
          if (viewModel.enabled) ...[
            const Divider(),
            SpSectionTitle(title: tr("page.sync.status_section")),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(tr("page.sync.last_sync")),
              subtitle: Text(_lastSyncText(context, viewModel)),
            ),
            ListTile(
              leading: viewModel.busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_outlined),
              title: Text(tr("page.sync.sync_now")),
              subtitle: viewModel.statusMessage == null
                  ? null
                  : Text(_statusText(viewModel)),
              onTap: viewModel.busy ? null : () => viewModel.syncNow(),
            ),
          ],
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  String _lastSyncText(BuildContext context, SyncViewModel viewModel) {
    final DateTime? lastSyncedAt = viewModel.lastSyncedAtIso == null
        ? null
        : DateTime.tryParse(viewModel.lastSyncedAtIso!);
    if (lastSyncedAt == null) return tr("page.sync.never_synced");
    return MaterialLocalizations.of(context).formatFullDate(lastSyncedAt);
  }

  String _statusText(SyncViewModel viewModel) {
    if (viewModel.statusMessage == 'page.sync.synced_with_changes') {
      return tr(
        "page.sync.synced_with_changes",
        args: [(viewModel.lastSyncedChanges ?? 0).toString()],
      );
    }
    return tr(viewModel.statusMessage!);
  }

  void _showServerSheet(BuildContext context, SyncViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SyncServerSheet(viewModel: viewModel),
    );
  }
}

class _SyncServerSheet extends StatefulWidget {
  const _SyncServerSheet({required this.viewModel});

  final SyncViewModel viewModel;

  @override
  State<_SyncServerSheet> createState() => _SyncServerSheetState();
}

class _SyncServerSheetState extends State<_SyncServerSheet> {
  late final TextEditingController _serverUrl;
  late final TextEditingController _username;
  late final TextEditingController _appPassword;
  late final TextEditingController _passphrase;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _serverUrl = TextEditingController(
      text: widget.viewModel.serverUrlController.text,
    );
    _username = TextEditingController(
      text: widget.viewModel.usernameController.text,
    );
    _appPassword = TextEditingController(
      text: widget.viewModel.appPasswordController.text,
    );
    _passphrase = TextEditingController(
      text: widget.viewModel.passphraseController.text,
    );
  }

  @override
  void dispose() {
    _serverUrl.dispose();
    _username.dispose();
    _appPassword.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _serverUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr("page.sync.server_url"),
              ),
              validator: (value) {
                final String url = SyncViewModel.normalizeServerUrl(
                  value ?? '',
                );
                if (url.isEmpty) return tr("page.sync.error_missing_field");
                if (!SyncViewModel.isServerUrlSecure(url))
                  return tr("page.sync.error_https_required");
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _username,
              decoration: InputDecoration(labelText: tr("page.sync.username")),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? tr("page.sync.error_missing_field")
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _appPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr("page.sync.app_password"),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passphrase,
              obscureText: true,
              decoration: InputDecoration(
                labelText: tr("page.sync.passphrase"),
                helperText: tr("page.sync.passphrase_hint"),
              ),
              validator: (value) {
                if (value == null || value.isEmpty)
                  return tr("page.sync.error_missing_field");
                if (!SyncViewModel.isPassphraseAcceptable(value))
                  return tr("page.sync.error_weak_passphrase");
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                widget.viewModel.serverUrlController.text = _serverUrl.text;
                widget.viewModel.usernameController.text = _username.text;
                widget.viewModel.appPasswordController.text = _appPassword.text;
                widget.viewModel.passphraseController.text = _passphrase.text;
                await widget.viewModel.save();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(tr("button.save")),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
