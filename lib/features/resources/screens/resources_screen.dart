import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../data/resources_repository.dart';

final _resourcesRepoProvider =
    Provider<ResourcesRepository>((ref) => ResourcesRepository());

final _constitutionProvider = FutureProvider<String?>((ref) async {
  final role = ref.watch(activeClubRoleProvider);
  if (role == null) return null;
  return ref.read(_resourcesRepoProvider).getConstitution(role.clubId);
});

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  bool _editing = false;
  late TextEditingController _editController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _startEditing(String? current) {
    _editController.text = current ?? '';
    setState(() => _editing = true);
  }

  Future<void> _save() async {
    final role = ref.read(activeClubRoleProvider);
    if (role == null) return;
    setState(() => _isSaving = true);
    try {
      await ref
          .read(_resourcesRepoProvider)
          .saveConstitution(role.clubId, _editController.text);
      ref.invalidate(_constitutionProvider);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeClubRoleProvider);
    final isPresident = role?.isPresident ?? false;
    final contentAsync = ref.watch(_constitutionProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: isPresident && !_editing
          ? contentAsync.whenOrNull(
              data: (content) => FloatingActionButton(
                onPressed: () => _startEditing(content),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.edit_rounded, color: Colors.white),
              ),
            )
          : null,
      body: Column(
        children: [
          GradientHeader(
            title: 'Resources',
            badge: const GradientHeaderBadge(
              icon: Icons.menu_book_rounded,
              label: 'Club Constitution',
            ),
            trailing: _editing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => setState(() => _editing = false),
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Cancel'),
                      ),
                      _isSaving
                          ? const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : TextButton(
                              onPressed: _save,
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.white),
                              child: const Text('Save',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                    ],
                  )
                : null,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: contentAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (content) {
            if (_editing) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _editController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'Write the club constitution here...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              );
            }

            if (content == null || content.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded,
                        size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('No constitution added yet.',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (isPresident) ...[
                      const SizedBox(height: 4),
                      const Text('Tap the edit button to add one.',
                          style:
                              TextStyle(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.7),
              ),
            );
          },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
