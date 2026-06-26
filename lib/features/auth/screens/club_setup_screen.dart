import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../providers/auth_providers.dart';

class ClubSetupScreen extends ConsumerStatefulWidget {
  const ClubSetupScreen({super.key});

  @override
  ConsumerState<ClubSetupScreen> createState() => _ClubSetupScreenState();
}

class _ClubSetupScreenState extends ConsumerState<ClubSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isCheckingName = false;
  bool? _nameAvailable;
  String? _errorMessage;
  String _lastCheckedName = '';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkNameAvailability(String name) async {
    if (name.trim().length < 2) {
      setState(() => _nameAvailable = null);
      return;
    }
    if (name.trim() == _lastCheckedName) return;

    setState(() => _isCheckingName = true);
    try {
      final available = await ref
          .read(authRepositoryProvider)
          .isClubNameAvailable(name.trim());
      if (mounted) {
        setState(() {
          _nameAvailable = available;
          _lastCheckedName = name.trim();
        });
      }
    } finally {
      if (mounted) setState(() => _isCheckingName = false);
    }
  }

  Future<void> _createClub() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nameAvailable == false) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).createClub(_nameController.text.trim());
      ref.invalidate(userClubRolesProvider);
      if (mounted) context.go('/club-switcher');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final roles = ref.read(userClubRolesProvider).valueOrNull ?? [];
            final hasApproved = roles.any((r) => r.isApproved);
            if (hasApproved) {
              if (context.mounted) context.go('/club-switcher');
            } else {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/register');
            }
          },
        ),
        title: const Text('Create Club'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _buildHeader(context),
                      const SizedBox(height: 32),
                      _buildNameField(),
                      const SizedBox(height: 8),
                      _buildNameStatus(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    _ErrorBanner(message: _errorMessage!),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed:
                        (_isLoading || _nameAvailable == false) ? null : _createClub,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Create Club'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Give your club a unique name.',
            style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _createClub(),
      onChanged: (v) {
        setState(() => _nameAvailable = null);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_nameController.text == v) _checkNameAvailability(v);
        });
      },
      decoration: InputDecoration(
        labelText: 'Club Name',
        prefixIcon: const Icon(Icons.groups_rounded),
        suffixIcon: _isCheckingName
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Club name is required';
        if (v.trim().length < 2) return 'Name must be at least 2 characters';
        if (_nameAvailable == false) return 'This name is already taken';
        return null;
      },
    );
  }

  Widget _buildNameStatus() {
    if (_nameAvailable == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          _nameAvailable! ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 16,
          color: _nameAvailable! ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 6),
        Text(
          _nameAvailable! ? 'Name is available' : 'Name is already taken',
          style: TextStyle(
            fontSize: 13,
            color: _nameAvailable! ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
