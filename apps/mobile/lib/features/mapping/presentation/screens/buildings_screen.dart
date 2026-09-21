import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/models/building_model.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/state/spatial_state.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_status_chip.dart';

/// Campus Buildings Directory Screen
/// Owner: Nishant (Phase 2 — Application Routing)
class BuildingsScreen extends ConsumerStatefulWidget {
  const BuildingsScreen({super.key});

  @override
  ConsumerState<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends ConsumerState<BuildingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spatialState = ref.watch(spatialStateProvider);
    final spatialNotifier = ref.read(spatialStateProvider.notifier);

    final filteredBuildings = spatialState.availableBuildings.where((b) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return b.name.toLowerCase().contains(q) ||
          b.category.toLowerCase().contains(q) ||
          b.address.toLowerCase().contains(q);
    }).toList();

    return AppScaffold(
      title: 'Campus Buildings',
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search buildings, facilities...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Active Building Status Banner
          if (spatialState.selectedBuilding != null)
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primarySubtle,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Active: ${spatialState.selectedBuilding!.name}',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRouter.visitor),
                    child: const Text('Open Visitor Mode'),
                  ),
                ],
              ),
            ),

          // Buildings List
          Expanded(
            child: filteredBuildings.isEmpty
                ? Center(
                    child: Text(
                      'No buildings match "$_searchQuery"',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: filteredBuildings.length,
                    separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final building = filteredBuildings[index];
                      final isSelected = spatialState.selectedBuilding?.id == building.id;

                      return _BuildingCard(
                        building: building,
                        isSelected: isSelected,
                        onSelect: () => spatialNotifier.selectBuilding(building),
                        onOpenMap: () {
                          spatialNotifier.selectBuilding(building);
                          Navigator.pushNamed(context, AppRouter.map);
                        },
                        onOpenVisitor: () {
                          spatialNotifier.selectBuilding(building);
                          Navigator.pushNamed(context, AppRouter.visitor);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final BuildingModel building;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenVisitor;

  const _BuildingCard({
    required this.building,
    required this.isSelected,
    required this.onSelect,
    required this.onOpenMap,
    required this.onOpenVisitor,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onSelect,
      variant: AppCardVariant.outlined,
      borderColor: isSelected ? AppColors.primary : AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.secondarySubtle,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.apartment,
                  color: isSelected ? Colors.white : AppColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            building.name,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const AppStatusChip(
                            label: 'SELECTED',
                            status: AppStatusType.active,
                            isCompact: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      building.address,
                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        AppStatusChip(
                          label: building.category.toUpperCase(),
                          status: AppStatusType.info,
                          isCompact: true,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${building.metadata['floors'] ?? 1} Floors Mapped',
                          style: AppTypography.labelSmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined, size: 16),
                label: const Text('Map'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: AppTypography.labelSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton.icon(
                onPressed: onOpenVisitor,
                icon: const Icon(Icons.directions_walk, size: 16),
                label: const Text('Visitor Mode'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: AppTypography.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
