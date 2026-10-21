# Spec: Discovery Swipe Feature (Module 2 – Huy)

- **Branch:** `feature/discovery-swipe`
- **Stack:** Flutter, Riverpod (`Notifier`), go_router, Cloud Firestore, SharedPreferences, `appinio_swiper`, `geolocator`
- **Trạng thái:** ĐÃ CHỐT – đã implement

## 1. Quyết định đã chốt

| # | Vấn đề | Quyết định |
|---|---|---|
| Q1 | Vị trí tính km | Dùng `geolocator`; lưu `location` (GeoPoint) vào `users/{uid}`. Từ chối quyền → ẩn khoảng cách, không áp filter distance. |
| Q2 | Prompts | Chỉ **hiển thị** ở Deep View; dữ liệu seed thẳng Firestore (`users/{uid}.prompts`). |
| Q3 | Super Like | Không giới hạn số lượng. |
| Q4 | Block | Thuộc module Sơn. Discovery chỉ **đọc** mảng `blocked_users` trên `users/{uid}`; không tạo collection mới, không có nút Block. |
| Q5 | Popup Match | Thuộc module Đức Anh. Discovery nhận `matchId` và gọi popup; giữ dialog hiện có tới khi module 3 thay thế. |

## 2. Phạm vi

| Mã | Hạng mục | Hiện trạng → việc làm |
|---|---|---|
| S1 | Discovery Swipe Card (Hard) | Nâng cấp `discovery_screen.dart`: gesture 3 hướng, xoay góc, overlay, phân trang |
| S2 | Filter & Preferences (Medium) | Làm mới `discovery_filter_screen.dart` |
| S3 | Deep View (Medium) | Mở rộng `view_profile_screen.dart`: prompts, khoảng cách, sở thích chung |
| D1 | Query user khả dụng | `getDiscoveryPage`: loại swiped + blocked, phân trang cursor |
| D2 | Ghi swipe | `recordSwipe` hỗ trợ `super_like` |
| D3 | SharedPreferences | `min_age`, `max_age`, `max_distance`, `interested_in` |

**Ngoài phạm vi:** Undo/Rewind (Dũng), popup Match & chat (Đức Anh), Block/Report (Sơn), nhập prompts, quota Super Like.

## 3. Hành vi

### 3.1 Swipe Card

| Kéo | Action | Overlay | `action` ghi vào `swipes` |
|---|---|---|---|
| Phải | Like | LIKE xanh lá | `like` |
| Trái | Pass | NOPE đỏ | `nope` |
| Lên | Super Like | SUPER LIKE xanh dương | `super_like` |
| Xuống | không cho phép | – | – |

- Thẻ xoay tối đa 15° theo hướng kéo; overlay đậm dần theo khoảng kéo; thả dưới ngưỡng thì bật về.
- 3 nút dưới thẻ: Pass / Super Like / Like, cùng animation với gesture.
- Thẻ hiển thị tên + tuổi, khoảng cách, tối đa 3 tag (tag chung được tô nổi), tap vùng thông tin mở Deep View.
- Match: `recordSwipe` trả `matchId` → hiện popup match.
- AppBar: icon filter (→ `/discovery/filter`), profile, chat + badge.
- Empty state: "Bạn đã xem hết người phù hợp" + nút Chỉnh bộ lọc / Tải lại. Error state: thông báo + Thử lại.
- Bỏ 3 tab giới tính; `cfg_gender_filter` cũ được đọc làm default cho `interested_in`.

### 3.2 Lazy-load / pagination

- `pageSize = 20`; tải trang đầu khi vào màn hình hoặc khi filter đổi (reset toàn bộ).
- Khi số thẻ còn lại `<= 5` và `hasMore` → prefetch trang kế, không chặn UI.
- Danh sách thẻ chỉ **tăng** (không xoá thẻ đã quẹt) để index của `AppinioSwiper` không lệch; `seenIds` chống trùng.

### 3.3 Filter (`/discovery/filter`)

| Control | Widget | Phạm vi | Default | Key |
|---|---|---|---|---|
| Khoảng tuổi | `RangeSlider` | 18–60 | 18–35 | `min_age`, `max_age` |
| Khoảng cách tối đa | `Slider` | 1–100 km | 50 | `max_distance` |
| Quan tâm đến | Chips Nữ/Nam/Khác/Tất cả | – | Tất cả | `interested_in` |
| Sở thích | Chips đa chọn + switch "chỉ người có sở thích chung với tôi" | – | trống / tắt | `filter_interests`, `require_common_interest` |

Chỉ ghi SharedPreferences khi bấm **Áp dụng**; **Đặt lại** về default; Back bỏ thay đổi.

### 3.4 Deep View

- Album ảnh `PageView` vuốt ngang + dot indicator; không có ảnh → placeholder.
- Bio, **prompts** (card câu hỏi/trả lời), khoảng cách, sở thích (chung được tô nổi + "N sở thích chung").
- Nút Pass / Super Like / Like chỉ hiện khi mở từ Discovery. API vẫn nhận `Map` để không phá `chat_screen`.

## 4. Data

### 4.1 `users/{uid}` (mở rộng)

| Field | Dart | Ghi chú |
|---|---|---|
| `location` | `GeoPoint?` | cập nhật khi vào Discovery nếu có quyền vị trí |
| `prompts` | `List<ProfilePrompt>` | `[{question, answer}]`, seed thủ công |
| `tags` (có sẵn) | `List<String>` | dùng làm sở thích |
| `blocked_users` | `List<String>` | **chỉ đọc**; `toMap()` không xuất field này |

`toMap()` chỉ xuất `location`/`prompts` khi có giá trị, nên các luồng lưu hồ sơ khác (onboarding, edit) không vô tình xoá chúng.

### 4.2 `swipes/{myId}_{targetId}`

`swiper_id`, `swiped_id`, `action ∈ {like, nope, super_like}`, `created_at`. Match khi đối phương có `action ∈ {like, super_like}`. matchId xác định `sorted(a,b).join('_')` + `set()` để không tạo match trùng.

### 4.3 Query

1. **Excluded ids** (tải một lần mỗi lần reload, cập nhật cục bộ khi quẹt): `swipes where swiper_id == me` ∪ `me.blocked_users` ∪ `{me}`.
2. **Server:** `users [where gender == g] startAfterDocument(cursor) limit(fetchSize)` – không cần composite index.
3. **Client:** loại excluded; loại ứng viên có `blocked_users` chứa mình; loại hồ sơ trống (`full_name` rỗng); tuổi ngoài khoảng; xa hơn `max_distance` (chỉ khi cả hai có vị trí); không khớp sở thích đã chọn / không có sở thích chung (nếu bật).
4. **Lấp đầy trang:** lặp tối đa 5 vòng cho tới khi đủ `pageSize` hoặc hết dữ liệu (`docs.length < fetchSize`).
5. **Sắp xếp trong trang:** nhiều sở thích chung hơn trước, bằng nhau thì gần hơn trước.

Đánh đổi: lọc tuổi ở client để khỏi cần index `gender + age`; có thể tốn thêm lượt đọc khi filter hẹp.

### 4.4 SharedPreferences

| Key | Kiểu | Default |
|---|---|---|
| `min_age` | int | 18 |
| `max_age` | int | 35 |
| `max_distance` | int (km) | 50 |
| `interested_in` | String (`Nữ`/`Nam`/`Khác`/`all`) | `all` (hoặc `cfg_gender_filter` cũ) |
| `filter_interests` | List<String> | `[]` |
| `require_common_interest` | bool | false |

## 5. File

```
lib/
├─ core/routes/app_router.dart                 SỬA  + /discovery/filter
├─ core/providers/app_providers.dart           SỬA  + locationServiceProvider
├─ core/utils/geo_utils.dart                   MỚI  haversineKm
├─ core/utils/discovery_logic.dart             MỚI  filterCandidates (hàm thuần, có test)
├─ data/models/profile_prompt.dart             MỚI
├─ data/models/discovery_filter.dart           MỚI
├─ data/models/discovery_candidate.dart        MỚI
├─ data/models/user_model.dart                 SỬA  + location, prompts, blocked_users
├─ data/services/location_service.dart         MỚI
├─ data/services/preferences_service.dart      SỬA  + key filter
├─ data/services/firestore_service.dart        SỬA  getDiscoveryPage, super_like, matchId xác định
└─ features/discovery/presentation/
   ├─ screens/discovery_screen.dart            SỬA
   ├─ screens/discovery_filter_screen.dart     MỚI
   └─ viewmodels/
      ├─ discovery_view_model.dart             SỬA
      └─ discovery_filter_view_model.dart      MỚI
lib/features/profile/presentation/screens/view_profile_screen.dart   SỬA
test/                                          MỚI  unit test
```

## 6. Acceptance Criteria

**Swipe**
- [ ] Kéo phải/trái/lên ghi đúng 1 doc `swipes/{me}_{target}` với `action` tương ứng.
- [ ] Thẻ xoay, overlay đúng, thả sớm thì bật về; 3 nút cho kết quả như gesture.
- [ ] Hai bên like (kể cả super_like) → đúng 1 match, trả `matchId`.

**Pagination**
- [ ] Mỗi lần fetch ≤ `pageSize`; tự tải trang kế khi còn ≤ 5 thẻ; không fetch lặp vô hạn khi hết dữ liệu.
- [ ] Không xuất hiện: chính mình, người đã quẹt, người mình đã block, người đã block mình, hồ sơ trống.

**Filter**
- [ ] Áp dụng filter → Discovery reload đúng kết quả; tắt/mở app vẫn giữ 4 giá trị.
- [ ] Đặt lại về default; Back không lưu.

**Deep View**
- [ ] Vuốt ngang đổi ảnh; hiển thị bio, prompts, khoảng cách, sở thích chung.

**Chất lượng**
- [ ] `flutter analyze` không lỗi mới; `flutter test` pass.
- [ ] Doc user cũ (thiếu `location`/`prompts`) không crash.

## 7. Giả định cần xác nhận với nhóm

- `blocked_users` là mảng uid nằm ở `users/{uid}` – xác nhận với **Sơn**.
- `interested_in` dùng cùng giá trị gender (`Nữ`/`Nam`/`Khác`) hoặc `all` – báo **Khánh**.
- `swipes.action` có thêm `super_like` – báo **Dũng**.
