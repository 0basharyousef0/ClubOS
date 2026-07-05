import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../providers/polls_providers.dart';

class PollCreateScreen extends ConsumerStatefulWidget {
  const PollCreateScreen({super.key});

  @override
  ConsumerState<PollCreateScreen> createState() => _PollCreateScreenState();
}

class _PollCreateScreenState extends ConsumerState<PollCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _isYesNo = true;
  String? _audience;
  final Set<String> _customVoterIds = {};
  DateTime? _closesAt;
  TimeOfDay _closingTime = const TimeOfDay(hour: 23, minute: 59);
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> _buildOptions() {
    if (_isYesNo) return ['Yes', 'No'];
    return _optionControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audience == null) {
      setState(() => _errorMessage = 'Please select who can see this poll.');
      return;
    }
    final options = _buildOptions();
    if (!_isYesNo && options.length < 2) {
      setState(
          () => _errorMessage = 'Please add at least 2 options.');
      return;
    }
    if (_audience == AppConstants.audienceCustom &&
        _customVoterIds.isEmpty) {
      setState(() =>
          _errorMessage = 'Please select at least one member to vote.');
      return;
    }

    final role = ref.read(activeClubRoleProvider);
    if (role == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(pollsRepositoryProvider);
      final eligible = await repo.resolveAudience(
        clubId: role.clubId,
        audience: _audience!,
        customUserIds: _customVoterIds.toList(),
      );
      if (eligible.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = _audience == AppConstants.audienceMyDirectors
              ? 'No directors report to you yet.'
              : 'This audience has no members.';
        });
        return;
      }
      await repo.createPoll(
            clubId: role.clubId,
            title: _titleController.text.trim(),
            description: _descController.text.trim().isEmpty
                ? null
                : _descController.text.trim(),
            audience: _audience!,
            options: options,
            eligibleUserIds: eligible,
            closesAt: _closesAt,
          );
      ref.invalidate(pollsProvider);
      if (mounted) context.go('/polls');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _closesAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _closesAt = DateTime(
          picked.year, picked.month, picked.day,
          _closingTime.hour, _closingTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closingTime,
    );
    if (picked != null && _closesAt != null) {
      setState(() {
        _closingTime = picked;
        _closesAt = DateTime(
          _closesAt!.year, _closesAt!.month, _closesAt!.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeClubRoleProvider);
    final isPresident = role?.isPresident ?? false;

    final audienceOptions = isPresident
        ? [
            (value: AppConstants.audienceAll, label: 'All Members'),
            (value: AppConstants.audienceVpsOnly, label: 'VPs & President only'),
            (value: AppConstants.audienceCustom, label: 'Custom — pick members'),
          ]
        : [
            (value: AppConstants.audienceAll, label: 'All Members'),
            (value: AppConstants.audienceVpsOnly, label: 'VPs & President only'),
            (value: AppConstants.audienceMyDirectors, label: 'My Directors'),
            (value: AppConstants.audienceCustom, label: 'Custom — pick members'),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/polls'),
        ),
        title: const Text('New Poll'),
      ),
      body: SafeArea(
        child: Column(
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
                      const SizedBox(height: 8),

                      // Title
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Question',
                          hintText: 'What do you want to ask?',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Question is required'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Poll type
                      Text('Poll Type',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _TypeChip(
                            label: 'Yes / No',
                            selected: _isYesNo,
                            onTap: () => setState(() => _isYesNo = true),
                          ),
                          const SizedBox(width: 10),
                          _TypeChip(
                            label: 'Multiple Choice',
                            selected: !_isYesNo,
                            onTap: () => setState(() => _isYesNo = false),
                          ),
                        ],
                      ),

                      if (!_isYesNo) ...[
                        const SizedBox(height: 16),
                        Text('Options',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        ..._optionControllers.asMap().entries.map((entry) {
                          final i = entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _optionControllers[i],
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration: InputDecoration(
                                      labelText: 'Option ${i + 1}',
                                    ),
                                  ),
                                ),
                                if (_optionControllers.length > 2)
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline,
                                        color: AppColors.error),
                                    onPressed: () => setState(() {
                                      _optionControllers[i].dispose();
                                      _optionControllers.removeAt(i);
                                    }),
                                  ),
                              ],
                            ),
                          );
                        }),
                        if (_optionControllers.length < 5)
                          TextButton.icon(
                            onPressed: () => setState(() =>
                                _optionControllers
                                    .add(TextEditingController())),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Option'),
                          ),
                      ],

                      const SizedBox(height: 24),

                      // Audience
                      Text('Who can vote?',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ...audienceOptions.map((opt) => _AudienceTile(
                            label: opt.label,
                            value: opt.value,
                            selected: _audience == opt.value,
                            onTap: () =>
                                setState(() => _audience = opt.value),
                          )),
                      if (_audience == AppConstants.audienceCustom) ...[
                        const SizedBox(height: 8),
                        _MemberChecklist(
                          selectedIds: _customVoterIds,
                          onToggle: (id) => setState(() {
                            _customVoterIds.contains(id)
                                ? _customVoterIds.remove(id)
                                : _customVoterIds.add(id);
                          }),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Closing date
                      Text('Closing Date (optional)',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  color: AppColors.textSecondary, size: 18),
                              const SizedBox(width: 10),
                              Text(
                                _closesAt == null
                                    ? 'No closing date'
                                    : DateFormat('MMMM d, y').format(_closesAt!),
                                style: TextStyle(
                                  color: _closesAt == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              if (_closesAt != null)
                                GestureDetector(
                                  onTap: () => setState(() {
                                    _closesAt = null;
                                    _closingTime = const TimeOfDay(hour: 23, minute: 59);
                                  }),
                                  child: const Icon(Icons.clear_rounded,
                                      size: 18,
                                      color: AppColors.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (_closesAt != null) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickTime,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.access_time_rounded,
                                    color: AppColors.textSecondary, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  _closingTime.format(context),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                const Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Create Poll'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberChecklist extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _MemberChecklist({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(pollMemberPickerProvider);
    final myUserId = ref.watch(activeClubRoleProvider)?.userId;

    return membersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => const Text('Could not load members.',
          style: TextStyle(color: AppColors.error, fontSize: 13)),
      data: (members) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            for (final m in members)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                value: selectedIds.contains(m.userId),
                onChanged: (_) => onToggle(m.userId),
                title: Text(
                  m.userId == myUserId
                      ? '${m.profile?.fullName ?? 'Member'} (You)'
                      : m.profile?.fullName ?? 'Member',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  m.roleDisplayName,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AudienceTile extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;
  const _AudienceTile(
      {required this.label,
      required this.value,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color:
                      selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
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
        borderRadius: BorderRadius.circular(10),
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
