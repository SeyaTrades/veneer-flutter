import 'package:flutter/material.dart';
import '../core/app_cfg.dart';
import '../data/app_ctrl.dart';
import '../data/app_data.dart';

class AuthScrn extends StatefulWidget { // mock auth gate + persisted planner behavior settings
  final AppCtrl ctrl;
  final VoidCallback onStudio;

  const AuthScrn({super.key, required this.ctrl, required this.onStudio});

  @override
  State<AuthScrn> createState() => _AuthScrnState();
}

class _AuthScrnState extends State<AuthScrn> {
  final _formKey = GlobalKey<FormState>();
  bool _isSignup = false;
  String _email = '';
  String _pass = '';
  String _name = '';

  Future<void> _submit(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    if (_isSignup) {
      await widget.ctrl.doSignup(_email.trim(), _pass, _name.trim());
    } else {
      await widget.ctrl.doLogin(_email.trim(), _pass);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isSignup ? 'Profile saved on this device' : 'Signed in on this device')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiCfg.of(context);
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.ctrl,
        builder: (context, _) {
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ui.pad * 1.5),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    widget.ctrl.isGuest ? _buildForm(context) : _buildCard(),
                    const SizedBox(height: 16),
                    _buildSet(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard() {
    final user = widget.ctrl.curUser!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: PalCfg.border)),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: PalCfg.accent,
            child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: const TextStyle(fontSize: 22, color: Colors.white)),
          ),
          const SizedBox(height: 10),
          Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: PalCfg.ink)),
          Text(user.email, style: const TextStyle(color: PalCfg.muted)),
          const SizedBox(height: 10),
          Text('Saved Rooms: ${widget.ctrl.savedRooms.length}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (widget.ctrl.hasDraft) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.onStudio,
                style: FilledButton.styleFrom(backgroundColor: PalCfg.accent),
                child: const Text('Return to Studio & Save Draft'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: () => widget.ctrl.doLogout(), icon: const Icon(Icons.logout, size: 18), label: const Text('Sign Out')),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: PalCfg.border)),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isSignup ? 'Create Account' : 'Sign In to Veneer', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: PalCfg.ink)),
            const SizedBox(height: 4),
            const Text('Your rooms stay on this device. Use the demo account to try saving one.', style: TextStyle(fontSize: 12, color: PalCfg.muted)),
            const SizedBox(height: 16),
            if (_isSignup) ...[
              TextFormField(
                decoration: const InputDecoration(labelText: 'Display Name', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a name' : null,
                onSaved: (v) => _name = v ?? '',
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
              validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              onSaved: (v) => _email = v ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.length < 4) ? 'Use at least 4 characters' : null,
              onSaved: (v) => _pass = v ?? '',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _submit(context),
              style: FilledButton.styleFrom(backgroundColor: PalCfg.accent),
              child: Text(_isSignup ? 'Create Account' : 'Sign In'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await widget.ctrl.doDemo();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed in as Demo User')));
                }
              },
              child: const Text('Use demo account'),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignup = !_isSignup),
              child: Text(_isSignup ? 'Already have an account? Sign In' : 'Need an account? Register'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSet() {
    final p = widget.ctrl.prefs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PalCfg.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: PalCfg.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Planner Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: PalCfg.ink)),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Units', style: TextStyle(fontSize: 14)),
            trailing: SegmentedButton<UnitKind>(
              segments: const [
                ButtonSegment(value: UnitKind.metric, label: Text('Metric', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: UnitKind.imperial, label: Text('Imperial', style: TextStyle(fontSize: 11))),
              ],
              selected: {p.unit},
              onSelectionChanged: (v) => widget.ctrl.setPrefs(p.copyWith(unit: v.first)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Snap to Grid (${p.unit == UnitKind.metric ? "5 cm" : "2 in"})', style: const TextStyle(fontSize: 14)),
            value: p.snapOn,
            onChanged: (v) => widget.ctrl.setPrefs(p.copyWith(snapOn: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Blueprint Grid', style: TextStyle(fontSize: 14)),
            value: p.showGrid,
            onChanged: (v) => widget.ctrl.setPrefs(p.copyWith(showGrid: v)),
          ),
          const SizedBox(height: 6),
          const Text('When Switching Room Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          InputDecorator(
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), // avoids DropdownButtonFormField value/initialValue SDK drift
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SwitchRule>(
                isExpanded: true,
                isDense: true,
                value: p.switchRule,
                items: const [
                  DropdownMenuItem(value: SwitchRule.ask, child: Text('Ask me (Save / Keep / Load Latest)')),
                  DropdownMenuItem(value: SwitchRule.loadLast, child: Text('Auto-load my latest room for that type')),
                  DropdownMenuItem(value: SwitchRule.keepItems, child: Text('Keep current furniture across rooms')),
                  DropdownMenuItem(value: SwitchRule.blank, child: Text('Always start empty')),
                ],
                onChanged: (v) {
                  if (v != null) widget.ctrl.setPrefs(p.copyWith(switchRule: v));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}