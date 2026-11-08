import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app_colors.dart';
import '../../../data/models/discovery_filter.dart';
import '../../ViewModels/discovery_view_model.dart';

/// Danh sách sở thích để chọn trong bộ lọc.
const List<String> kFilterInterestOptions = [
  'Âm nhạc',
  'Du lịch',
  'Thể thao',
  'Đọc sách',
  'Game',
  'Thú cưng',
  'Ẩm thực',
  'Phim ảnh',
  'Yoga',
  'Cà phê',
  'Nghệ thuật',
  'Thiên nhiên',
];

const List<String> _genderOptions = ['Nữ', 'Nam', 'Khác', DiscoveryFilter.anyGender];

/// Màn hình bộ lọc khám phá: tuổi, khoảng cách, giới tính, sở thích chung.
class DiscoveryFilterScreen extends ConsumerStatefulWidget {
  const DiscoveryFilterScreen({super.key});

  @override
  ConsumerState<DiscoveryFilterScreen> createState() =>
      _DiscoveryFilterScreenState();
}

class _DiscoveryFilterScreenState extends ConsumerState<DiscoveryFilterScreen> {
  static const double _ageMin = 18;
  static const double _ageMax = 60;

  late DiscoveryFilter _draft;

  @override
  void initState() {
    super.initState();
    // Bản nháp: chỉ ghi SharedPreferences khi bấm "Áp dụng"
    _draft = ref.read(discoveryFilterProvider);
  }

  String _genderLabel(String v) => v == DiscoveryFilter.anyGender ? 'Tất cả' : v;

  Future<void> _apply() async {
    await ref.read(discoveryFilterProvider.notifier).apply(_draft);
    if (mounted) context.pop(true);
  }

  void _reset() => setState(() => _draft = const DiscoveryFilter());

  @override
  Widget build(BuildContext context) {
    final ageRange = RangeValues(
      _draft.minAge.clamp(_ageMin, _ageMax).toDouble(),
      _draft.maxAge.clamp(_ageMin, _ageMax).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bộ lọc khám phá'),
        actions: [
          TextButton(onPressed: _reset, child: const Text('Đặt lại')),
        ],
      ),
      body: ListView(
        // Chừa chỗ cho thanh điều hướng hệ thống để không che nút ở cuối
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewPadding.bottom + 24,
        ),
        children: [
          _section('Độ tuổi', '${_draft.minAge} - ${_draft.maxAge}'),
          RangeSlider(
            values: ageRange,
            min: _ageMin,
            max: _ageMax,
            divisions: (_ageMax - _ageMin).toInt(),
            activeColor: AppColors.primary,
            labels: RangeLabels(
              ageRange.start.round().toString(),
              ageRange.end.round().toString(),
            ),
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(
                minAge: v.start.round(),
                maxAge: v.end.round(),
              );
            }),
          ),
          const SizedBox(height: 16),
          _section('Khoảng cách tối đa', '${_draft.maxDistanceKm} km'),
          Slider(
            value: _draft.maxDistanceKm.clamp(1, 100).toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            activeColor: AppColors.primary,
            label: '${_draft.maxDistanceKm} km',
            onChanged: (v) => setState(() {
              _draft = _draft.copyWith(maxDistanceKm: v.round());
            }),
          ),
          if (ref.watch(discoveryViewModelProvider
                  .select((s) => !s.isLoading && s.myLocation == null)))
            const Row(
              children: [
                Icon(Icons.location_off_outlined,
                    size: 16, color: Colors.orange),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bật vị trí để lọc theo khoảng cách',
                    style: TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          _section('Quan tâm đến', null),
          Wrap(
            spacing: 8,
            children: _genderOptions
                .map((g) => ChoiceChip(
                      label: Text(_genderLabel(g)),
                      selected: _draft.interestedIn == g,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      onSelected: (_) => setState(
                          () => _draft = _draft.copyWith(interestedIn: g)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          _section('Sở thích chung', null),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: AppColors.primary,
            title: const Text('Chỉ hiện người có sở thích chung'),
            // Đã chọn chip thì luôn lọc theo chip, công tắc chỉ khóa được khi bỏ hết chip
            onChanged: _draft.interests.isNotEmpty
                ? null
                : (v) => setState(
                    () => _draft = _draft.copyWith(requireCommonInterest: v)),
            subtitle: Text(
              _draft.interests.isEmpty
                  ? 'Dùng sở thích trong hồ sơ của bạn'
                  : 'Dùng các sở thích đã chọn bên dưới',
              style: const TextStyle(fontSize: 12),
            ),
            value: _draft.requireCommonInterest,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: kFilterInterestOptions
                .map((t) => FilterChip(
                      label: Text(t),
                      selected: _draft.interests.contains(t),
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                      onSelected: (on) => setState(() {
                        final list = [..._draft.interests];
                        on ? list.add(t) : list.remove(t);
                        // Chọn chip là đang lọc theo sở thích -> bật công tắc cho khớp
                        _draft = _draft.copyWith(
                          interests: list,
                          requireCommonInterest: on ? true : null,
                        );
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _apply,
              child: const Text('Áp dụng'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String? trailing) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
