import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/constants.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../providers/meetings_providers.dart';

class MeetingCreateScreen extends ConsumerStatefulWidget {
  const MeetingCreateScreen({super.key});

  @override
  ConsumerState<MeetingCreateScreen> createState() =>
      _MeetingCreateScreenState();
}

class _MeetingCreateScreenState extends ConsumerState<MeetingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  String _recurrence = AppConstants.recurrenceOnce;
  int? _reminderMinutes;
  String? _audience;
  final Set<String> _customInviteeIds = {};
  bool _isLoading = false;
  String? _errorMessage;

  static const _recurrenceOptions = [
    (value: AppConstants.recurrenceOnce, label: 'Once'),
    (value: AppConstants.recurrenceDaily, label: 'Daily'),
    (value: AppConstants.recurrenceWeekly, label: 'Weekly'),
    (value: AppConstants.recurrenceBiweekly, label: 'Bi-weekly'),
    (value: AppConstants.recurrenceMonthly, label: 'Monthly'),
  ];

  static const List<({int? value, String label})> _reminderOptions = [
    (value: null, label: 'No reminder'),
    (value: 60, label: '1 hour before'),
    (value: 120, label: '2 hours before'),
    (value: 180, label: '3 hours before'),
    (value: 360, label: '6 hours before'),
    (value: 720, label: '12 hours before'),
    (value: 1440, label: '1 day before'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime? get _scheduledAt => _date == null
      ? null
      : DateTime(
          _date!.year, _date!.month, _date!.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final scheduledAt = _scheduledAt;
    if (scheduledAt == null) {
      setState(() => _errorMessage = 'Please pick a meeting date.');
      return;
    }
    if (scheduledAt.isBefore(DateTime.now())) {
      setState(() => _errorMessage = 'The meeting time must be in the future.');
      return;
    }
    if (_audience == null) {
      setState(() => _errorMessage = 'Please select who to invite.');
      return;
    }
    if (_audience == AppConstants.meetingAudienceCustom &&
        _customInviteeIds.isEmpty) {
      setState(() =>
          _errorMessage = 'Please select at least one member to invite.');
      return;
    }

    final role = ref.read(activeClubRoleProvider);
    if (role == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(meetingsRepositoryProvider);
      final attendees = await repo.resolveAudience(
        clubId: role.clubId,
        audience: _audience!,
        customUserIds: _customInviteeIds.toList(),
      );
      if (attendees.length <= 1 &&
          _audience == AppConstants.meetingAudienceMyDirectors) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No directors report to you yet.';
        });
        return;
      }
      await repo.createMeeting(
        clubId: role.clubId,
        title: _titleController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        audience: _audience!,
        scheduledAt: scheduledAt,
        recurrence: _recurrence,
        reminderOffsetMinutes: _reminderMinutes,
        attendeeUserIds: attendees,
      );
      ref.invalidate(meetingsProvider);
      if (mounted) context.go('/meetings');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeClubRoleProvider);
    final isPresident = role?.isPresident ?? false;

    final audienceOptions = isPresident
        ? [
            (value: AppConstants.meetingAudienceVps, label: 'VPs'),
            (
              value: AppConstants.meetingAudienceVpsDirectors,
              label: 'VPs & Directors'
            ),
            (
              value: AppConstants.meetingAudienceCustom,
              label: 'Custom — pick members'
            ),
          ]
        : [
            (value: AppConstants.meetingAudienceVps, label: 'VPs'),
            (
              value: AppConstants.meetingAudienceMyDirectors,
              label: 'My Directors'
            ),
            (
              value: AppConstants.meetingAudienceCustom,
              label: 'Custom — pick members'
            ),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/meetings'),
        ),
        title: const Text('Schedule Meeting'),
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
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'What is this meeting about?',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Title is required'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText: 'Agenda, meeting link, room…',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Date & time
                      Text('When',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _PickerField(
                              icon: Icons.calendar_today_rounded,
                              label: _date == null
                                  ? 'Pick a date'
                                  : DateFormat('EEE, MMM d, y').format(_date!),
                              placeholder: _date == null,
                              onTap: _pickDate,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _PickerField(
                              icon: Icons.access_time_rounded,
                              label: _time.format(context),
                              placeholder: false,
                              onTap: _pickTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Recurrence
                      Text('Repeats',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final opt in _recurrenceOptions)
                            _Chip(
                              label: opt.label,
                              selected: _recurrence == opt.value,
                              onTap: () =>
                                  setState(() => _recurrence = opt.value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Reminder
                      Text('Automated reminder',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                        'Everyone invited also gets notified this long '
                        'before the meeting starts.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final opt in _reminderOptions)
                            _Chip(
                              label: opt.label,
                              selected: _reminderMinutes == opt.value,
                              onTap: () => setState(
                                  () => _reminderMinutes = opt.value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Audience
                      Text('Who is invited?',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      ...audienceOptions.map((opt) => _AudienceTile(
                            label: opt.label,
                            selected: _audience == opt.value,
                            onTap: () =>
                                setState(() => _audience = opt.value),
                          )),
                      if (_audience == AppConstants.meetingAudienceCustom) ...[
                        const SizedBox(height: 8),
                        _InviteeChecklist(
                          selectedIds: _customInviteeIds,
                          onToggle: (id) => setState(() {
                            _customInviteeIds.contains(id)
                                ? _customInviteeIds.remove(id)
                                : _customInviteeIds.add(id);
                          }),
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
                        : const Text('Schedule Meeting'),
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

class _InviteeChecklist extends ConsumerWidget {
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const _InviteeChecklist({
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(meetingInviteePickerProvider);
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        // Material ancestor so the CheckboxListTile ink renders
        // (a bare DecoratedBox would swallow it).
        child: Material(
          color: AppColors.surface,
          child: Column(
            children: [
              for (final m in members)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppColors.primary,
                  value: m.userId == myUserId ||
                      selectedIds.contains(m.userId),
                  // The scheduler is always in their own meeting.
                  onChanged:
                      m.userId == myUserId ? null : (_) => onToggle(m.userId),
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
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool placeholder;
  final VoidCallback onTap;
  const _PickerField({
    required this.icon,
    required this.label,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: placeholder
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
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
  final bool selected;
  final VoidCallback onTap;
  const _AudienceTile(
      {required this.label, required this.selected, required this.onTap});

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
