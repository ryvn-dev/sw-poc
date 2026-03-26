import 'package:flutter/material.dart';
import 'package:sw_ble/sw_ble.dart';
import 'nearby_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  int _mbtiIndex        = 0;
  bool _loading         = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onStart() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await SwBle.setProfile(
        name: _nameController.text.trim(),
        mbtiIndex: _mbtiIndex,
      );
      await SwBle.startBle();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NearbyScreen()),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'e.g. Alice',
                  border: OutlineInputBorder(),
                ),
                maxLength: 18,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _mbtiIndex,
                decoration: const InputDecoration(
                  labelText: 'MBTI Type',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(kMbtiTypes.length, (i) {
                  return DropdownMenuItem(
                    value: i,
                    child: Text(kMbtiTypes[i]),
                  );
                }),
                onChanged: (v) => setState(() => _mbtiIndex = v ?? 0),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _loading ? null : _onStart,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start Broadcasting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
