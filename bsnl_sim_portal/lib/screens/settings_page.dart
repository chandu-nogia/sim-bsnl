import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../state/sim_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.store});
  final SimStore store;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _url;
  bool _testing = false;
  String? _testMsg;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.store.auth.apiUrl ?? widget.store.apiBase);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.saveApiUrl(_url.text);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Server se data load ho raha hai…')),
      );
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testMsg = null;
    });
    try {
      await widget.store.saveApiUrl(_url.text);
      final msg = await widget.store.testConnection();
      setState(() {
        _testOk = true;
        _testMsg = msg;
      });
    } catch (e) {
      setState(() {
        _testOk = false;
        _testMsg = '$e';
      });
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vercel + Render + Atlas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. MongoDB Atlas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BsnlColors.navy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    'mongodb.com/atlas → free M0 cluster\n'
                    'Database Access → user banao\n'
                    'Network Access → Allow 0.0.0.0/0 (Render ke liye)\n'
                    'Connect → Drivers → URI copy\n\n'
                    'Render env + local backend/.env:\n'
                    'MONGODB_URI=mongodb+srv://USER:PASS@cluster.../bsnl_sim',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '2. Local server',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BsnlColors.navy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    'cd backend\ncp .env.example .env\nnpm install\nnpm start\n\n'
                    'API: http://localhost:5050/api/health',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '3. Live host',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BsnlColors.navy,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    'UI: Vercel (Flutter web)\n'
                    'API: Render (Node.js)\n'
                    'DB: MongoDB Atlas\n\n'
                    'API: https://bsnl-sim-api.onrender.com',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '4. API URL',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: BsnlColors.navy,
                        ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _url,
                    decoration: const InputDecoration(
                      labelText: 'API URL',
                      hintText: 'http://localhost:5050  ya  https://bsnl-sim-api.onrender.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save & load'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _testing ? null : _test,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Test connection'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await widget.store.disconnect();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Local mode')),
                          );
                        },
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                  if (_testMsg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _testMsg!,
                      style: TextStyle(
                        color: _testOk ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Data MongoDB Atlas collection "sims" mein jata hai. '
                'Flutter web Vercel par hai, API Render par. '
                'Release build Render API URL use karti hai; yahan override bhi kar sakte ho.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
