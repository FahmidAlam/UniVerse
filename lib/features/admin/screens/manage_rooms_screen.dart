// PHASE A: ManageRoomsScreen — Room CRUD, Explicit Room Classifications, R10/R11 Availability, and R14 Semester Pool (55/45 Master-Detail)
import 'package:flutter/material.dart';
import 'package:universe/core/constants/app_constants.dart';
import 'package:universe/core/models/admin_catalog_models.dart';
import 'package:universe/core/models/timetable_config_model.dart';
import 'package:universe/core/theme/app_colors.dart';
import 'package:universe/core/theme/app_spacing.dart';
import 'package:universe/core/theme/app_text_styles.dart';
import 'package:universe/features/admin/controllers/timetable_rooms_controller.dart';
import 'package:universe/features/admin/widgets/r15_slot_selector.dart';
import 'package:universe/shared/utils/phosphor_compat.dart';
import 'package:universe/shared/widgets/desktop_shell_scope.dart';
import 'package:universe/shared/widgets/u_adaptive_overlay.dart';
import 'package:universe/shared/widgets/u_app_bar.dart';
import 'package:universe/shared/widgets/u_button.dart';
import 'package:universe/shared/widgets/u_card.dart';
import 'package:universe/shared/widgets/u_chip.dart';
import 'package:universe/shared/widgets/u_empty_state.dart';
import 'package:universe/shared/widgets/u_loading.dart';
import 'package:universe/shared/widgets/u_text_field.dart';

enum RoomFilter {
  all,
  activePool,
  generalClassrooms,
  cseComputerLabs,
  eclLabs,
  physicsLab,
}

class ManageRoomsScreen extends StatefulWidget {
  final TimetableRoomsController? controller;

  const ManageRoomsScreen({super.key, this.controller});

  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  late final TimetableRoomsController _controller;
  late final bool _ownsController;
  RoomFilter _activeFilter = RoomFilter.all;
  TimetableRoom? _selectedRoom;
  bool _isCreatingNew = false;
  String _searchQuery = '';

  // In-memory specialized lab availability matrices (R10, R11) per room ID
  final Map<String, Map<String, bool>> _labAvailability = {};
  // In-memory exclusive courses bound to Physics Lab (R11)
  final List<String> _physicsBoundCourses = ['PHY-1102', 'PHY-1202', 'PHY-1104'];

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TimetableRoomsController();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  List<TimetableRoom> _getFilteredRooms(List<TimetableRoom> rooms) {
    var list = rooms;
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              (r.building?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    switch (_activeFilter) {
      case RoomFilter.all:
        return list;
      case RoomFilter.activePool:
        return list.where((r) => r.isActive).toList();
      case RoomFilter.generalClassrooms:
        return list.where((r) => r.isGeneralClassroom).toList();
      case RoomFilter.cseComputerLabs:
        return list.where((r) => r.isComputerLab).toList();
      case RoomFilter.eclLabs:
        return list.where((r) => r.isEclLab).toList();
      case RoomFilter.physicsLab:
        return list.where((r) => r.isPhysicsLab).toList();
    }
  }

  String _filterLabel(RoomFilter filter) {
    switch (filter) {
      case RoomFilter.all:
        return 'All';
      case RoomFilter.activePool:
        return 'Active Semester Pool [R14]';
      case RoomFilter.generalClassrooms:
        return 'General Classrooms';
      case RoomFilter.cseComputerLabs:
        return 'CSE Computer Labs';
      case RoomFilter.eclLabs:
        return 'ECL Labs (EEE) [R10]';
      case RoomFilter.physicsLab:
        return 'Physics Lab [R11]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopShell = DesktopShellScope.isDesktopOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isDesktopShell
          ? null
          : const UAppBar(
              title: 'Room Pools',
              subtitle: 'Dynamic pools & lab availability (R10, R11, R14)',
              showBackButton: true,
            ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: ULoading.spinner());
          }
          final filteredRooms = _getFilteredRooms(_controller.rooms);
          final activeCount = _controller.rooms.where((r) => r.isActive).length;

          if (_selectedRoom != null &&
              !filteredRooms.any((r) => r.id == _selectedRoom!.id) &&
              !_isCreatingNew) {
            _selectedRoom = filteredRooms.isNotEmpty ? filteredRooms.first : null;
          } else if (_selectedRoom == null && filteredRooms.isNotEmpty && !_isCreatingNew) {
            _selectedRoom = filteredRooms.first;
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final usableWidth = constraints.maxWidth;
              final isMasterDetail = usableWidth >= 900;

              return Column(
                children: [
                  _buildPolicyHeader(context),
                  _buildFilterBar(
                    filteredRooms.length,
                    activeCount,
                    _controller.rooms.length,
                    usableWidth,
                  ),
                  Expanded(
                    child: filteredRooms.isEmpty && !_isCreatingNew
                        ? const UEmptyState(
                            icon: PhosphorIconsRegular.door,
                            title: 'No rooms match filter',
                            message: 'Try selecting a different filter chip.',
                          )
                        : isMasterDetail
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left 55% Master List
                                  Expanded(
                                    flex: 55,
                                    child: _buildMasterList(filteredRooms, isMasterDetail: true),
                                  ),
                                  const VerticalDivider(color: AppColors.border, width: 1),
                                  // Right 45% Docked Detail Inspector
                                  Expanded(
                                    flex: 45,
                                    child: _buildInspectorPane(_selectedRoom, isSheet: false),
                                  ),
                                ],
                              )
                            : _buildMasterList(filteredRooms, isMasterDetail: false),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPolicyHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSubtle,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: AppSpacing.radiusSm,
            ),
            child: Text(
              'RULES R10, R11 & R14',
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Active theory pool dynamic toggling (R14) · ECL lab shared windows (R10) · Physics lab exclusive bindings (R11)',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(int filteredCount, int activeCount, int totalCount, double usableWidth) {
    final isCompact = usableWidth < 768;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgSubtle,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: UTextField(
                  label: 'Search Rooms',
                  hint: 'Search rooms by name or building...',
                  prefixIcon: PhosphorIconsRegular.magnifyingGlass,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              AppSpacing.smGap,
              UButton(
                label: isCompact ? 'Add' : 'Add Room',
                icon: PhosphorIconsRegular.plus,
                fullWidth: false,
                onPressed: () {
                  setState(() {
                    _isCreatingNew = true;
                    _selectedRoom = const TimetableRoom(
                      id: '',
                      name: '',
                      capacity: 60,
                      isActive: true,
                      inActiveSemesterPool: true,
                      classification: RoomClassification.generalClassroom,
                    );
                  });
                  if (usableWidth < 900) {
                    _openEditorModal(_selectedRoom!);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: AppSpacing.radiusSm,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '$activeCount Active in Pool · $totalCount Total',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ...RoomFilter.values.map((f) {
                final isSelected = _activeFilter == f;
                return UChip(
                  label: _filterLabel(f),
                  isActive: isSelected,
                  onTap: () => setState(() => _activeFilter = f),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMasterList(List<TimetableRoom> rooms, {required bool isMasterDetail}) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: UCard(
        isTopLit: true,
        padding: EdgeInsets.zero,
        child: ListView.separated(
          itemCount: rooms.length,
          separatorBuilder: (context, index) =>
              const Divider(color: AppColors.border, height: 1),
          itemBuilder: (context, index) {
            final r = rooms[index];
            final isSelected = isMasterDetail && _selectedRoom?.id == r.id && !_isCreatingNew;

            return InkWell(
              onTap: () {
                setState(() {
                  _isCreatingNew = false;
                  _selectedRoom = r;
                });
                if (!isMasterDetail) {
                  _openEditorModal(r);
                }
              },
              child: Container(
                color: isSelected ? AppColors.surfaceInteractive : Colors.transparent,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // 3px semantic left bar on selected row only (Unslop #1, #13)
                    Container(
                      width: 3.5,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _roomBadgeColor(r).withValues(alpha: 0.15),
                        borderRadius: AppSpacing.radiusSm,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : _roomBadgeColor(r).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Icon(
                        _roomIcon(r),
                        color: _roomBadgeColor(r),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Text(
                                r.name,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                              _buildRoomTypePill(r),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            r.building ?? 'Main Academic Campus',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    // Right-aligned Tabular Capacity
                    if (r.capacity != null)
                      Text(
                        '${r.capacity} seats',
                        style: AppTextStyles.numeric.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    const SizedBox(width: AppSpacing.md),
                    // R14 Dynamic Pool Switch
                    Tooltip(
                      message: 'Toggle Active in Semester Pool (R14)',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r.isActive ? 'IN POOL' : 'OFF',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: r.isActive ? AppColors.roleTeacher : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: r.isActive,
                            activeThumbColor: AppColors.roleTeacher,
                            onChanged: (_) => _controller.toggleActive(r),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _roomBadgeColor(TimetableRoom r) {
    switch (r.roomClassification) {
      case RoomClassification.cseComputerLab:
        return AppColors.roleTeacher;
      case RoomClassification.eclLab:
        return AppColors.warning;
      case RoomClassification.physicsLab:
        return Colors.indigoAccent;
      case RoomClassification.lectureGallery:
        return AppColors.primary;
      case RoomClassification.generalClassroom:
        return AppColors.info;
    }
  }

  IconData _roomIcon(TimetableRoom r) {
    switch (r.roomClassification) {
      case RoomClassification.cseComputerLab:
        return PhosphorIconsRegular.laptop;
      case RoomClassification.eclLab:
        return PhosphorIconsRegular.cpu;
      case RoomClassification.physicsLab:
        return PhosphorIconsRegular.atom;
      case RoomClassification.lectureGallery:
        return PhosphorIconsRegular.chalkboard;
      case RoomClassification.generalClassroom:
        return PhosphorIconsRegular.door;
    }
  }

  Widget _buildRoomTypePill(TimetableRoom r) {
    final cls = r.roomClassification;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: _roomBadgeColor(r).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _roomBadgeColor(r).withValues(alpha: 0.4)),
      ),
      child: Text(
        cls.shortName.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: _roomBadgeColor(r),
        ),
      ),
    );
  }

  Widget _buildInspectorPane(TimetableRoom? r, {required bool isSheet}) {
    if (r == null) {
      return const Center(child: Text('Select a room to configure'));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSheet ? AppSpacing.md : AppSpacing.lg),
      child: _RoomDetailInspector(
        controller: _controller,
        room: r,
        isCreatingNew: _isCreatingNew,
        availabilityMatrix: _labAvailability[r.id] ?? r.declaredWindowMatrix,
        onAvailabilityChange: (matrix) {
          setState(() => _labAvailability[r.id] = matrix);
        },
        physicsBoundCourses: r.boundCourseCodes.isNotEmpty ? r.boundCourseCodes : _physicsBoundCourses,
        onAddPhysicsCourse: (c) {
          setState(() {
            if (!_physicsBoundCourses.contains(c)) _physicsBoundCourses.add(c);
          });
        },
        onRemovePhysicsCourse: (c) {
          setState(() => _physicsBoundCourses.remove(c));
        },
        onSaved: (savedRoom) {
          setState(() {
            _selectedRoom = savedRoom;
            _isCreatingNew = false;
          });
        },
      ),
    );
  }

  void _openEditorModal(TimetableRoom r) {
    showUAdaptiveModal<void>(
      context: context,
      title: _isCreatingNew ? 'Create New Room' : 'Room Inspector · ${r.name}',
      subtitle: 'Classifications, Pool Toggles & Lab Availability Matrices',
      builder: (ctx) => _buildInspectorPane(r, isSheet: true),
    );
  }
}

class _RoomDetailInspector extends StatefulWidget {
  final TimetableRoomsController controller;
  final TimetableRoom room;
  final bool isCreatingNew;
  final Map<String, bool> availabilityMatrix;
  final ValueChanged<Map<String, bool>> onAvailabilityChange;
  final List<String> physicsBoundCourses;
  final ValueChanged<String> onAddPhysicsCourse;
  final ValueChanged<String> onRemovePhysicsCourse;
  final ValueChanged<TimetableRoom> onSaved;

  const _RoomDetailInspector({
    required this.controller,
    required this.room,
    this.isCreatingNew = false,
    required this.availabilityMatrix,
    required this.onAvailabilityChange,
    required this.physicsBoundCourses,
    required this.onAddPhysicsCourse,
    required this.onRemovePhysicsCourse,
    required this.onSaved,
  });

  @override
  State<_RoomDetailInspector> createState() => _RoomDetailInspectorState();
}

class _RoomDetailInspectorState extends State<_RoomDetailInspector> {
  int _slotCount = 6;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _newCourseCodeCtrl = TextEditingController();

  RoomClassification _classification = RoomClassification.generalClassroom;
  bool _inActiveSemesterPool = true;
  late Map<String, bool> _availability;
  late List<String> _boundCourses;
  bool _saving = false;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _initDraft();
  }

  @override
  void didUpdateWidget(covariant _RoomDetailInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id || oldWidget.isCreatingNew != widget.isCreatingNew) {
      _initDraft();
    }
  }

  void _initDraft() {
    _nameController.text = widget.room.name;
    _buildingController.text = widget.room.building ?? '';
    _capacityController.text = widget.room.capacity?.toString() ?? '60';
    _classification = widget.room.roomClassification;
    _inActiveSemesterPool = widget.room.inActiveSemesterPool;
    _availability = Map<String, bool>.from(widget.availabilityMatrix);
    _boundCourses = List<String>.from(widget.physicsBoundCourses);
    _isDirty = widget.isCreatingNew;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _buildingController.dispose();
    _capacityController.dispose();
    _newCourseCodeCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room name is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final capacity = int.tryParse(_capacityController.text.trim()) ?? 60;
    final isLab = _classification.isLab;
    final isGallery = _classification == RoomClassification.lectureGallery;

    final updatedData = <String, dynamic>{
      'id': widget.room.id.isNotEmpty ? widget.room.id : 'room-${name.toLowerCase().replaceAll(' ', '-')}',
      'name': name,
      'building': _buildingController.text.trim(),
      'capacity': capacity,
      'is_lab': isLab,
      'is_gallery': isGallery,
      'is_active': _inActiveSemesterPool,
      'in_active_semester_pool': _inActiveSemesterPool,
      'classification': _classification.name,
      'bound_course_codes': _boundCourses,
      'declared_window_matrix': _availability,
    };

    final ok = await widget.controller.save(
      existing: widget.isCreatingNew ? null : widget.room,
      data: updatedData,
    );
    widget.onAvailabilityChange(_availability);

    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _isDirty = false;
    });

    if (ok) {
      final updatedRoom = TimetableRoom.fromMap(updatedData);
      widget.onSaved(updatedRoom);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Room configuration saved for $name.'),
          backgroundColor: AppColors.roleTeacher,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = AppConstants.weekDays;
    final slotCount = _slotCount;
    final name = _nameController.text.trim();

    return UCard(
      isTopLit: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Truthful Storage Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isCreatingNew ? 'Add Room to Pool' : 'Room Inspector ($name)',
                    style: AppTextStyles.h4,
                  ),
                ],
              ),
              if (_isDirty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.warning),
                  ),
                  child: Text(
                    'Unsaved Changes',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(color: AppColors.border, height: 24),

          // Physical Attributes
          Text('PHYSICAL ATTRIBUTES', style: AppTextStyles.labelCaps),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: UTextField(
                  label: 'Room Name / Number',
                  hint: 'e.g. Room 302 / CSE Lab 1',
                  controller: _nameController,
                  onChanged: (_) => _markDirty(),
                ),
              ),
              AppSpacing.smGap,
              Expanded(
                flex: 5,
                child: UTextField(
                  label: 'Building & Floor',
                  hint: 'e.g. Academic Building A, Floor 3',
                  controller: _buildingController,
                  onChanged: (_) => _markDirty(),
                ),
              ),
              AppSpacing.smGap,
              Expanded(
                flex: 3,
                child: UTextField(
                  label: 'Capacity (Seats)',
                  hint: 'e.g. 60',
                  controller: _capacityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => _markDirty(),
                ),
              ),
            ],
          ),
          const Divider(color: AppColors.border, height: 28),

          // Room Classification Selector
          Text('ROOM CLASSIFICATION & RULES R10/R11/R14', style: AppTextStyles.labelCaps),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: RoomClassification.values.map((cls) {
              final isSel = _classification == cls;
              return UChip(
                label: cls.displayName,
                isActive: isSel,
                onTap: () {
                  setState(() {
                    _classification = cls;
                    _markDirty();
                  });
                },
              );
            }).toList(),
          ),
          AppSpacing.smGap,
          // R14 Active Semester Pool Toggle
          Text('R14 Active Semester Classroom Pool', style: AppTextStyles.labelCaps),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.bgSubtle,
              borderRadius: AppSpacing.radiusSm,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active in Semester Pool (R14)', style: AppTextStyles.bodyMedium),
                      Text(
                        'Includes room in solver candidate allocation pool for the active semester',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Switch(
                  value: _inActiveSemesterPool,
                  activeThumbColor: AppColors.roleTeacher,
                  onChanged: (v) {
                    setState(() {
                      _inActiveSemesterPool = v;
                      _markDirty();
                    });
                  },
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 28),

          // Exclusive Course Codes Binding (Physics Lab R11 or specialized labs)
          if (_classification == RoomClassification.physicsLab || _classification == RoomClassification.eclLab) ...[
            Text('EXCLUSIVE COURSE CODE BINDINGS (RULE R11)', style: AppTextStyles.labelCaps),
            const SizedBox(height: 4),
            Text(
              'Solver restricts this laboratory strictly to bound course codes (zero cross-contamination).',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ..._boundCourses.map((c) => Chip(
                      label: Text(c, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.surfaceElevated,
                      deleteIcon: const Icon(PhosphorIconsRegular.x, size: 12),
                      onDeleted: () {
                        setState(() {
                          _boundCourses.remove(c);
                          _markDirty();
                        });
                      },
                    )),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: UTextField(
                    label: 'Course Code',
                    hint: 'e.g. PHY-1102',
                    controller: _newCourseCodeCtrl,
                  ),
                ),
                AppSpacing.smGap,
                UButton(
                  label: 'Bind Course',
                  icon: PhosphorIconsRegular.plus,
                  variant: UButtonVariant.secondary,
                  fullWidth: false,
                  onPressed: () {
                    final code = _newCourseCodeCtrl.text.trim().toUpperCase();
                    if (code.isNotEmpty && !_boundCourses.contains(code)) {
                      setState(() {
                        _boundCourses.add(code);
                        _newCourseCodeCtrl.clear();
                        _markDirty();
                      });
                    }
                  },
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 28),
          ],

          // R15-Synced Declared Availability Matrix (R10/R11)
          Text('DECLARED AVAILABILITY WINDOW MATRIX (R10 / R11)', style: AppTextStyles.labelCaps),
          const SizedBox(height: 6),
          R15SlotSelector(onChanged: (count) {
            if (mounted) setState(() => _slotCount = count);
          }),
          const SizedBox(height: 4),
          Text(
            'Mark slots where this specialized facility is available for scheduling (Emerald = Open / Unblocked).',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(52),
              border: TableBorder.all(color: AppColors.border),
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.bgElevated),
                  children: [
                    Container(
                      height: 28,
                      alignment: Alignment.center,
                      child: Text('Slot', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    for (final d in days)
                      Container(
                        height: 28,
                        alignment: Alignment.center,
                        child: Text(d.substring(0, 3), style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                for (var slot = 1; slot <= slotCount; slot++)
                  TableRow(
                    children: [
                      Container(
                        height: 32,
                        alignment: Alignment.center,
                        child: Text(
                          'P$slot',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      for (final d in days) _buildMatrixCell(d, slot),
                    ],
                  ),
              ],
            ),
          ),
          // Action Bar: Visible only when isDirty or creating new (Unslop #2)
          if (_isDirty || widget.isCreatingNew) ...[
            const Divider(color: AppColors.border, height: 28),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (!widget.isCreatingNew && widget.room.id.isNotEmpty)
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.trash, color: AppColors.error),
                    tooltip: 'Delete Room',
                    onPressed: () => _confirmDelete(context),
                  ),
                UButton(
                  label: 'Discard',
                  variant: UButtonVariant.secondary,
                  fullWidth: false,
                  onPressed: () => setState(() => _initDraft()),
                ),
                UButton(
                  label: 'Save Room Configuration',
                  isLoading: _saving,
                  fullWidth: false,
                  onPressed: _save,
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
  }

  Widget _buildMatrixCell(String day, int slot) {
    // Friday Jummah Prayer Window Hard Constraint (friday_no_p4): Non-negotiable hard block
    final isFridayJummah = (day == 'Friday' || day.startsWith('Fri')) && slot == 4;
    if (isFridayJummah) {
      return Tooltip(
        message: 'Hard Constraint: Friday Jummah Prayer Window (friday_no_p4) — No classes permitted',
        child: Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(PhosphorIconsRegular.lock, size: 10, color: AppColors.error),
              Text(
                'JUMMAH',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final key = '${day.substring(0, 3)}:${slot - 1}';
    final isOpen = _availability[key] ?? true;

    return InkWell(
      onTap: () {
        setState(() {
          _availability[key] = !isOpen;
          _markDirty();
        });
      },
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: isOpen ? AppColors.roleTeacher.withValues(alpha: 0.18) : AppColors.background,
          border: Border.all(
            color: isOpen ? AppColors.roleTeacher : AppColors.border,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          isOpen ? PhosphorIconsRegular.check : PhosphorIconsRegular.prohibit,
          size: 14,
          color: isOpen ? AppColors.roleTeacher : AppColors.textMuted,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final name = _nameController.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Delete Room', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to delete room $name? This will remove it from all scheduling pools.',
          style: AppTextStyles.bodySm,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.controller.delete(widget.room.id);
              if (mounted && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Room $name deleted.'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
