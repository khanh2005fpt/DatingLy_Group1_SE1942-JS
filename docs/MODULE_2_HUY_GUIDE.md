# Module 2: Khám phá & Quẹt thẻ — Tài liệu ôn (Huy)

> Mục đích: đọc để hiểu **mỗi file làm gì**, **luồng chạy ra sao**, và **cách test từng feature** khi demo / bị hỏi.
> Xem thêm: [REVIEW_MODULE_2_HUY.md](REVIEW_MODULE_2_HUY.md) (review lỗi + giải thích khái niệm), [specs/discovery-swipe-feature-spec.md](specs/discovery-swipe-feature-spec.md).

---

## 1. Kiến trúc tổng quan (MVVM + Riverpod)

```
View (Screen/Widget)  ──ref.watch / ref.read──►  ViewModel (Riverpod Notifier)
                                                     │ gọi
                                                     ▼
                                              Repository (Firestore, GPS, SharedPreferences)
                                                     │ trả về
                                                     ▼
                                                 Model (UserModel, DiscoveryFilter)
```

- **View** chỉ vẽ UI và bắt sự kiện (quẹt, bấm nút). Không gọi Firestore trực tiếp.
- **ViewModel** giữ state (danh sách thẻ, đang tải, lỗi, vị trí của mình…) và logic (tải trang, prefetch, ghi swipe).
- **Repository** nói chuyện với bên ngoài: Firestore, GPS, bộ nhớ máy.
- **Model** là dữ liệu thuần.

---

## 2. Các file của module 2

### 2.1 Model (`lib/data/models/`)

| File | Là gì | Dùng để làm gì |
| --- | --- | --- |
| `discovery_filter.dart` | Class `DiscoveryFilter` (immutable) | Gói cấu hình lọc: `minAge`, `maxAge`, `maxDistanceKm`, `interestedIn` (`Nữ`/`Nam`/`Khác`/`all`), `interests`, `requireCommonInterest`. Có giới hạn (18–60 tuổi, 1–100 km), giá trị mặc định (18–35, 50 km, tất cả), `copyWith`, và `==`/`hashCode` để Riverpod biết filter **có thật sự đổi** hay không (đổi mới reload). |
| `user_model.dart` (dùng chung) | `UserModel`, `ProfilePrompt` | Module 2 đọc: `age`, `gender`, `tags`, `location` (GeoPoint), `avatarUrls`, `bio`, `prompts {question, answer}`. |

### 2.2 Repository (`lib/data/repositories/`)

| File | Là gì | Dùng để làm gì |
| --- | --- | --- |
| `discovery_repository.dart` | `DiscoveryRepository` + hàm thuần `passesDiscoveryFilter` + class `DiscoveryPage` | Trái tim của module. Xem chi tiết bên dưới. |
| `geo_utils.dart` | Hàm `haversineKm(lat1, lon1, lat2, lon2)` | Tính khoảng cách đường chim bay (km) giữa 2 tọa độ. Dùng để lọc theo slider và hiện "X km". |
| `location_repository.dart` | `LocationRepository.getCurrentLocation()` | Dùng package `geolocator`: kiểm tra GPS bật chưa → xin quyền → lấy tọa độ (độ chính xác thấp, timeout 8 s). Lỗi / từ chối quyền thì trả `null` (không crash). |
| `setting_repository.dart` (dùng chung) | `loadDiscoveryFilter()` / `saveDiscoveryFilter()` | Lưu filter vào **SharedPreferences** với key: `min_age`, `max_age`, `max_distance`, `interested_in`, `filter_interests`, `require_common_interest`. Tắt app mở lại vẫn nhớ. |

**Bên trong `discovery_repository.dart`:**

- `passesDiscoveryFilter(...)` — hàm **thuần** (không gọi Firestore) quyết định 1 người có được hiện hay không. Loại nếu:
  1. là chính mình;
  2. `ghost_mode == true` (module Sơn);
  3. người đó đã block mình (`blocked_users` của họ chứa id mình);
  4. hồ sơ chưa có tên;
  5. tuổi ngoài khoảng;
  6. sai giới tính (khi không chọn "Tất cả");
  7. **mình có vị trí** mà họ không có `location`, hoặc xa hơn `maxDistanceKm`;
  8. đã chọn chip sở thích mà họ không có tag nào trùng.
- `getExcludedUserIds(myId)` — gom ID cần loại trước: chính mình + mọi người mình đã quẹt (collection `swipes`, `swiper_id == myId`) + người mình đã block.
- `getDiscoveryPage(...)` — tải 1 "trang" thẻ:
  - Query Firestore: `where age >= min`, `where age <= max`, `orderBy age`, `limit 30`, nếu có cursor thì `startAfterDocument(cursor)`.
  - Mỗi doc: bỏ nếu nằm trong `excludedIds` hoặc không qua `passesDiscoveryFilter`.
  - Lặp tối đa **5 vòng** đến khi gom đủ **20 thẻ**. Hết dữ liệu (trả về < 30 doc) thì `hasMore = false`.
  - Trả `DiscoveryPage { users, cursor, hasMore }`.
- `recordSwipe(myId, targetUserId, action)` — ghi `swipes/{myId}_{targetId}` với `action` = `like` / `nope` / `super_like`. Nếu là like/super_like thì đọc swipe **ngược chiều** `{targetId}_{myId}`; nếu đối phương cũng like → tạo `matches/{idNhỏ}_{idLớn}` (id cố định nên không trùng match) và trả về `matchId`.
- `getUsersWhoLikedMe(myId)` — danh sách người đã like mình mà mình chưa quẹt (tối đa 50). Dùng cho màn "Ai đã thích bạn".

### 2.3 ViewModel (`lib/UI/ViewModels/discovery_view_model.dart`)

| Thành phần | Dùng để làm gì |
| --- | --- |
| `SwipeAction` (enum) | `like`, `nope`, `superLike` → giá trị lưu Firestore `like` / `nope` / `super_like`. |
| `DiscoveryState` | State màn hình: `cards`, `isLoading`, `isLoadingMore`, `hasMore`, `errorMessage`, `myLocation`, `myTags`. |
| `DiscoveryFilterNotifier` (`discoveryFilterProvider`) | Giữ filter hiện tại. `build()` đọc từ SharedPreferences; `apply(filter)` lưu rồi cập nhật state. |
| `DiscoveryViewModel` (`discoveryViewModelProvider`) | Logic chính, `keepAlive` để chuyển tab không mất thẻ. |
| ├ `reload()` | Tải lại từ đầu: lấy GPS (và cập nhật `location` lên Firestore), lấy tags của mình, lấy danh sách loại trừ, tải trang 1. Ít thẻ thì gọi `loadMore()` luôn. |
| ├ `loadMore()` | Tải trang tiếp theo từ `_cursor`, bỏ thẻ trùng, nối vào `cards`. Lỗi thì đặt `errorMessage`. |
| ├ `_generation` | Bộ đếm "thế hệ": reload mới thì kết quả của lần tải cũ (về muộn) bị bỏ qua, tránh ghi đè state. |
| ├ `onCardConsumed(remaining)` | Gọi sau mỗi lần quẹt; còn ≤ 5 thẻ (`kPrefetchThreshold`) thì `loadMore()` (prefetch). |
| ├ `recordSwipe(targetId, action)` | Thêm id vào `_excluded` rồi gọi repository. |
| ├ `distanceTo(user)` | Khoảng cách tới người đó (null nếu thiếu vị trí). |
| └ `restore(userId)` | Cho Dũng gọi sau Rewind: bỏ id khỏi `_excluded` rồi reload. |
| `unreadCountProvider` | Tổng `unreadCount` của mọi match → badge đỏ trên icon chat. |

> Filter đổi → `ref.listen(discoveryFilterProvider)` trong `build()` tự gọi `reload()`. View không cần tự reload.
> `discovery_view_model.g.dart` là code **tự sinh** bởi `build_runner`, không sửa tay.

### 2.4 View (`lib/UI/Views/Screen/`)

| File | Route | Dùng để làm gì |
| --- | --- | --- |
| `discovery_screen.dart` | `/discovery` | Màn quẹt chính. `AppinioSwiper` (`maxAngle: 15`, `threshold: 80`, chỉ cho trái/phải/lên). Phải = Like, trái = Nope, lên = Super Like. Nhãn LIKE/NOPE/SUPER LIKE (`_StampOverlay`) hiện ~450 ms. 3 nút dưới (Bỏ qua / Super Like / Thích) gọi `_controller.swipeX()`. AppBar: hồ sơ, ♥ "Ai đã thích bạn" (badge số người), bộ lọc, chat (badge tin chưa đọc). Match → `showMatchCelebration` (của Đức Anh). |
| `_SwipeCard` (trong file trên) | — | 1 thẻ: ảnh full, chạm nửa trái/phải để đổi ảnh, chấm chỉ số ảnh, tên + tuổi, "X km" / "Dưới 1 km", tối đa 3 chip sở thích chung. Chạm vùng thông tin → mở hồ sơ chi tiết. |
| `discovery_filter_screen.dart` | `/discovery/filter` | `RangeSlider` tuổi 18–60, `Slider` 1–100 km, chip giới tính, chip sở thích, công tắc "Chỉ hiện người có sở thích chung". Sửa trên **bản nháp** `_draft`, chỉ lưu khi bấm **Áp dụng**. "Đặt lại" về mặc định. Bản debug có nút **Tạo 30 user giả / Xoá user giả**. |
| `view_profile_screen.dart` | (push) | Hồ sơ chi tiết: album vuốt ngang, bio, prompt (câu hỏi + trả lời), khoảng cách, số sở thích chung, nút Bỏ qua / Super Like / Thích (đóng màn rồi quẹt thẻ tương ứng). |
| `who_liked_you_screen.dart` | `/likes` | Danh sách người đã like mình, like lại → match → vào chat. **Sẽ bỏ** khi module 4 của Dũng merge (review 3.2). |

### 2.5 Test

`test/discovery_logic_test.dart`:

- 9 test cho `passesDiscoveryFilter`: hợp lệ, ngoài tuổi, sai giới tính, bị chặn, ghost mode, chưa có tên, quá xa, không có vị trí, chip sở thích lọc dù tắt công tắc.
- 1 test haversine Hà Nội – TP.HCM ≈ 1150 km.
- 2 test đọc / ghi filter qua SharedPreferences (mặc định và lưu-đọc lại đúng key).

---

## 3. Luồng chạy

### 3.1 Mở màn Discovery

```
DiscoveryScreen build
  └─ ref.watch(discoveryViewModelProvider)  → lần đầu: build() trả state isLoading=true
       └─ Future.microtask(reload)
            1. LocationRepository.getCurrentLocation()  (xin quyền GPS)
               └─ có vị trí → UserRepository.updateLocation() lên Firestore
            2. UserRepository.getUserProfile(myId)       → lấy tags của mình
            3. getExcludedUserIds(myId)                  → đã quẹt + đã block
            4. getDiscoveryPage(...)                      → trang 1 (≤ 20 thẻ)
            5. state = cards, isLoading=false
               └─ nếu ≤ 5 thẻ và hasMore → loadMore()
```

Màn hình hiện:
- `isLoading` → vòng xoay.
- Hết thẻ + có lỗi → thông báo lỗi + nút **Thử lại**.
- Hết thẻ + `hasMore` → vòng xoay và tự gọi `loadMore()` sau frame (`addPostFrameCallback`) — chống treo loading.
- Hết thẻ + hết dữ liệu → "Bạn đã xem hết người phù hợp" + **Chỉnh bộ lọc** / **Tải lại**.
- Còn thẻ → chồng thẻ quẹt.

### 3.2 Quẹt 1 thẻ

```
Người dùng kéo thẻ / bấm nút
  ├─ onSwipeBegin → hiện nhãn LIKE / NOPE / SUPER LIKE
  └─ onSwipeEnd
       1. _consumed = targetIndex (thẻ trên cùng mới)
       2. vm.onCardConsumed(còn lại) → còn ≤ 5 thì loadMore() (prefetch)
       3. vm.recordSwipe(user.id, action)
            ├─ _excluded.add(id)
            └─ repo.recordSwipe → ghi swipes/{me}_{them}
                 └─ like/super_like và đối phương đã like mình → tạo matches/{a}_{b}
       4. có matchId → showMatchCelebration (popup It's a Match)
       5. lỗi → SnackBar "Lỗi khi ghi nhận swipe"
```

### 3.3 Đổi bộ lọc

```
Bấm icon bộ lọc → /discovery/filter
  → chỉnh _draft → bấm "Áp dụng"
  → DiscoveryFilterNotifier.apply(filter)
       ├─ SettingRepository.saveDiscoveryFilter → SharedPreferences
       └─ state = filter
  → DiscoveryViewModel thấy filter đổi (ref.listen) → reload()
  → DiscoveryScreen thấy isLoading=true → reset _consumed = 0
```

Ghi chú: bật "Chỉ hiện người có sở thích chung" mà **không chọn chip** → dùng tags của chính mình làm danh sách sở thích để lọc (`_fetch`).

### 3.4 Lọc ở đâu?

| Điều kiện | Lọc ở | Lý do |
| --- | --- | --- |
| Tuổi | **Firestore** (`where` + `orderBy age`) | Giảm số doc phải tải. |
| Đã quẹt / mình đã block | Client (`excludedIds`) | Firestore không có `NOT IN` cho danh sách dài. |
| Giới tính, khoảng cách, sở thích, họ block mình, ghost mode, chưa có tên | Client (`passesDiscoveryFilter`) | Firestore chỉ cho range trên **1 field**, và không tự tính khoảng cách. |

### 3.5 Mở hồ sơ chi tiết

Chạm vùng tên/tuổi trên thẻ → `ViewProfileScreen` (truyền `distanceKm`, `myTags`, và 3 callback quẹt). Bấm Thích/Bỏ qua/Super Like trong hồ sơ → đóng màn và quẹt thẻ đó → chạy đúng luồng 3.2.

---

## 4. Cách test

### 4.1 Unit test (không cần máy ảo)

```bash
flutter test test/discovery_logic_test.dart
```

Kỳ vọng: tất cả pass. Chạy cả project: `flutter test`.

### 4.2 Chuẩn bị test tay

1. Chạy app bản **debug** (`flutter run`), đăng nhập, hoàn tất onboarding (có tên, tuổi, giới tính, sở thích).
2. **Cho phép quyền vị trí.** Trên máy ảo Android: `...` → Location → đặt tọa độ (ví dụ Hà Nội `21.0278, 105.8342`) rồi bấm *Set location*.
3. Vào **Bộ lọc** → kéo xuống dưới → bấm **Tạo 30 user giả**. SnackBar: "Đã tạo 30 user giả (5 người đã Like bạn)".
4. Đặt filter rộng để thấy nhiều thẻ: tuổi 18–60, 100 km, giới tính Tất cả, không chip sở thích → **Áp dụng**.

> Dọn dẹp sau khi test / trước khi nộp: bấm **Xoá user giả** (cùng màn Bộ lọc).

### 4.3 Checklist test từng feature

| # | Feature | Cách làm | Kỳ vọng |
| --- | --- | --- | --- |
| 1 | Quẹt phải = Like | Kéo thẻ sang phải | Nhãn **LIKE** xanh, thẻ bay đi. Firestore có `swipes/{me}_{them}` `action: like`. |
| 2 | Quẹt trái = Nope | Kéo sang trái | Nhãn **NOPE** đỏ, `action: nope`. |
| 3 | Quẹt lên = Super Like | Kéo lên | Nhãn **SUPER LIKE** xanh dương, `action: super_like`. |
| 4 | Quẹt xuống | Kéo xuống | Không cho quẹt, thẻ bật về. |
| 5 | Góc xoay | Kéo chậm sang ngang | Thẻ nghiêng tối đa ~15°; thả khi chưa quá ngưỡng thì thẻ trở lại. |
| 6 | 3 nút dưới | Bấm Bỏ qua / Super Like / Thích | Giống quẹt tương ứng. |
| 7 | Đổi ảnh trên thẻ | Chạm nửa phải / trái của ảnh | Ảnh đổi, thanh chỉ số ở trên đổi theo. |
| 8 | Match | Like một trong 5 người seed đầu (seed đã like mình) | Hiện popup **It's a Match** (của Đức Anh). Firestore có `matches/{idNhỏ}_{idLớn}`. |
| 9 | Không match trùng | Like lại cùng người (sau khi xóa swipe thủ công) | Vẫn chỉ 1 doc match (id cố định). |
| 10 | Không hiện lại người đã quẹt | Quẹt vài người → bấm **Tải lại** / mở lại app | Những người đã quẹt không xuất hiện nữa. |
| 11 | Pagination / prefetch | Quẹt liên tục > 20 thẻ (filter rộng) | Không bị khựng; log `[Discovery] trang 1: +N thẻ`. Hết thì hiện "Bạn đã xem hết…". |
| 12 | Hết người | Quẹt hết toàn bộ | Màn "Bạn đã xem hết người phù hợp" + nút Chỉnh bộ lọc / Tải lại. **Không** quay vòng mãi. |
| 13 | Lọc tuổi | Đặt 25–28 → Áp dụng | Chỉ thẻ có tuổi 25–28. |
| 14 | Lọc giới tính | Chọn **Nữ** | Chỉ thẻ giới tính Nữ (seed có cả Nam/Nữ/Khác). |
| 15 | Lọc khoảng cách | Đặt 10 km | Chỉ người ≤ 10 km, số km trên thẻ ≤ 10. Đặt 1 km thường sẽ hết người. |
| 16 | Không có vị trí | Từ chối quyền GPS → Tải lại | Thẻ không hiện "X km"; bộ lọc khoảng cách không áp dụng (vì không biết mình ở đâu). |
| 17 | Chip sở thích | Chọn chip "Du lịch" (không bật công tắc) | Chỉ người có tag Du lịch. |
| 18 | Sở thích chung | Bỏ hết chip, bật công tắc | Chỉ người có ≥ 1 tag trùng với tags của mình; chip chung hiện trên thẻ. |
| 19 | Lưu filter | Áp dụng filter → tắt hẳn app → mở lại → vào Bộ lọc | Giá trị vẫn như đã lưu. |
| 20 | Nháp filter | Kéo slider rồi bấm Back (không Áp dụng) | Filter không đổi, thẻ không reload. |
| 21 | Đặt lại | Bấm **Đặt lại** → Áp dụng | Về 18–35, 50 km, Tất cả, không chip. |
| 22 | Hồ sơ chi tiết | Chạm vùng tên trên thẻ | Album vuốt ngang, bio, prompt (seed có 2 prompt), "Cách bạn X km", "N sở thích chung". |
| 23 | Quẹt từ hồ sơ | Bấm Thích trong hồ sơ | Đóng hồ sơ, thẻ đó bay phải, ghi swipe như #1. |
| 24 | Block | Block một người (module Sơn) hoặc người đó block mình → Tải lại | Không còn thấy nhau (cả hai chiều). |
| 25 | Ghost mode | Ở tài khoản B bật ghost mode → tài khoản A Tải lại | A không thấy B. |
| 26 | Ai đã thích bạn | Icon ♥ trên AppBar | Badge = số người đã like mình chưa quẹt; mở ra thấy 5 user seed. |
| 27 | Badge chat | Có tin chưa đọc ở một match | Badge đỏ trên icon chat = tổng tin chưa đọc ("9+" nếu > 9). |
| 28 | Lỗi mạng | Tắt mạng → Tải lại | Hiện thông báo lỗi + nút **Thử lại** (không hiện "đã xem hết"). |

### 4.4 Xem dữ liệu trên Firebase Console

- `users/{id}`: `age`, `gender`, `tags`, `location`, `ghost_mode`, `blocked_users`, `prompts`.
- `swipes/{swiper}_{swiped}`: `swiper_id`, `swiped_id`, `action`, `created_at`.
- `matches/{idNhỏ}_{idLớn}`: `users`, `last_message: "Hai bạn đã tương hợp!"`.

Muốn quẹt lại từ đầu: xóa các doc `swipes` có `swiper_id` = id của mình rồi bấm **Tải lại**.

---

## 5. Câu hỏi hay bị hỏi khi demo

- **Sao không tải hết user một lần?** Tốn lượt đọc Firestore và chậm. Tải 20 thẻ/trang, còn ≤ 5 thì tải trước.
- **Sao giới tính không lọc trên Firestore?** Đã có range trên `age`; Firestore chỉ cho range + `orderBy` trên 1 field, thêm điều kiện khác cần composite index và vẫn không tính được khoảng cách. Lọc ở client cho đơn giản, gom hết vào 1 hàm thuần để test.
- **Hai người like nhau cùng lúc có tạo 2 match không?** Không, match id = 2 user id sắp xếp rồi ghép, nên cùng một doc.
- **Từ chối GPS thì sao?** App không crash; chỉ không hiện km và không lọc khoảng cách.
- **SharedPreferences khác Firestore thế nào?** SharedPreferences lưu trên máy (mỗi máy một bản), dùng cho filter; Firestore lưu trên server, dùng cho dữ liệu chung (user, swipe, match).
