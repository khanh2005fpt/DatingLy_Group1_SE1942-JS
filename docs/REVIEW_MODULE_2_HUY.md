# Review Module 2: Khám phá & Quẹt thẻ (Huy)

> Nhánh: `feature/discovery-swipe` · commit `3c30483` (21/10/2026, nqhuyyy11)
> Cách làm: đọc toàn bộ code thay đổi so với `main` và đối chiếu với file phân công. **Chưa chạy app, chưa chạy test** (máy kiểm tra không cài Flutter).

## 1. Đối chiếu yêu cầu

| Yêu cầu | Trạng thái | Code |
|---|---|---|
| Quẹt Like / Pass / Super Like | ✅ | `discovery_screen.dart`: phải = Like, trái = Pass, lên = Super Like, có nút bấm và nhãn LIKE/NOPE/SUPER LIKE |
| Hiệu ứng xoay góc | ✅ | `AppinioSwiper(maxAngle: 15)` |
| Lazy-load / pagination | 🟡 | `getDiscoveryPage` có `startAfterDocument` và tự tải trước khi còn ≤ 5 thẻ. **Có lỗi treo loading**, xem mục 2.1 |
| Màn Filter | ✅ | `discovery_filter_screen.dart`, route `/discovery/filter` |
| Slider khoảng cách (km) | 🟡 | Có `Slider` 1–100 km và `geolocator`. **Lọc không chặt**, xem mục 2.3 |
| Age range slider | ✅ | `RangeSlider` 18–60, lọc ngay trên Firestore (`where age` + `orderBy age`) |
| Lọc giới tính | ✅ | Chip Nữ / Nam / Khác / Tất cả. Giá trị khớp với onboarding |
| Lọc sở thích chung | 🟡 | Có, nhưng **các chip sở thích không có tác dụng nếu chưa bật công tắc**, xem mục 2.4 |
| Màn chi tiết: album vuốt ngang, bio | ✅ | `view_profile_screen.dart` |
| Câu trả lời prompt | 🟡 | Có hiển thị, nhưng **chưa có chỗ nào cho user nhập prompt**, chỉ user giả (seed) mới có. Xem mục 3.1 |
| Khoảng cách, sở thích chung | ✅ | "Cách bạn X km", "N sở thích chung" |
| Loại trừ người đã quẹt / đã block | ✅ | `getExcludedUserIds` + kiểm tra `blocked_users` cả hai chiều |
| Ghi swipe vào `swipes` | ✅ | `recordSwipe`. Doc id `swiper_swiped`, match id cố định nên không tạo match trùng |
| SharedPreferences `min_age`, `max_age`, `max_distance`, `interested_in` | ✅ | Đúng tên key. Thêm `filter_interests` và `require_common_interest` |
| Unit test | 🟡 | `test/discovery_logic_test.dart` có 3 test (haversine, đọc/ghi filter). **Chưa test logic lọc và phân trang** |

**Kết luận:** đã làm gần đủ yêu cầu. Còn **2 lỗi nên sửa trước khi demo** (mục 2.1 và 2.2) và một số chỗ cần thống nhất với các bạn khác khi merge.

---

## 2. Lỗi cần sửa

### 2.1 Treo vòng xoay loading mãi (nghiêm trọng)

**File:** `discovery_view_model.dart` (`loadMore`, `reload`) và `discovery_screen.dart` (`_buildBody`).

**Tình huống:** mỗi lần tải, `getDiscoveryPage` đọc tối đa 5 × 30 = 150 user. Nếu cả 150 người đều bị lọc bỏ (đã quẹt hết, filter chặt, khoảng cách xa…), kết quả trả về `users = []` nhưng `hasMore = true`.
- Màn hình thấy `exhausted && hasMore` nên hiện vòng xoay.
- Nhưng **không còn gì gọi `loadMore()` nữa**, vì `onCardConsumed` chỉ chạy khi quẹt thẻ, mà lúc này không còn thẻ để quẹt.
- Kết quả: **vòng xoay quay mãi**. Dễ gặp khi một tài khoản đã quẹt nhiều người.

**Cách sửa (chọn 1):**
- Trong `loadMore()`: nếu `fresh.isEmpty && page.hasMore` thì gọi tiếp `loadMore()` (đặt giới hạn số lần).
- Hoặc trong `_buildBody`: khi `exhausted && state.hasMore && !state.isLoadingMore` thì gọi `loadMore()` bằng `addPostFrameCallback`.

### 2.2 Tải lỗi thì hiện "Bạn đã xem hết"

**File:** `discovery_view_model.dart` (`loadMore`, khối `catch`).

Khi `loadMore` bị lỗi (mất mạng, timeout 20 giây), code đặt `hasMore: false` mà không đặt `errorMessage`. Màn hình hiện *"Bạn đã xem hết người phù hợp"* thay vì báo lỗi. Nên gán `errorMessage` để người dùng biết bấm "Thử lại".

### 2.3 Lọc khoảng cách không chặt

**File:** `firestore_service.dart` (`getDiscoveryPage`).

Hiện tại chỉ lọc khoảng cách khi **cả hai** người đều có vị trí:
- Nếu **mình** từ chối quyền GPS thì bộ lọc khoảng cách bị bỏ qua hoàn toàn, mà màn Filter không báo gì.
- Người **chưa có** `location` thì luôn lọt qua, dù đặt 1 km.

**Đề xuất:** khi không lấy được vị trí, hiện dòng "Bật vị trí để lọc theo khoảng cách" trên màn Filter. Người không có vị trí thì nên xếp xuống cuối hoặc ẩn đi.

### 2.4 Chọn sở thích mà không bật công tắc thì không có tác dụng

**File:** `discovery_filter_screen.dart`, `firestore_service.dart`.

Code chỉ lọc khi `requireCommonInterest == true`. Người dùng chọn chip "Du lịch" nhưng chưa bật công tắc thì kết quả **không đổi gì**.

**Cách sửa:** tự bật công tắc khi chọn chip, hoặc lọc theo `interests` mỗi khi danh sách này không rỗng.

### 2.5 Badge ở icon chat hiện sai số

**File:** `discovery_view_model.dart` (`matchCountProvider`), `discovery_screen.dart`.

Badge đặt tên `unreadCount` nhưng thực chất đang đếm **tổng số match**, nên có 10 match là hiện "9+" mãi. Nên cộng `unreadCount` của từng match: `matches.fold(0, (s, m) => s + m.unreadCount)`.

### 2.6 Lỗi nhỏ

- `loadMore` lỗi thì chỉ `debugPrint`, người dùng không biết (liên quan mục 2.2).
- `_buildBody` gán `_consumed = 0` ngay trong `build`. Chạy được, nhưng nên reset trong `ref.listen` khi `isLoading` chuyển sang `true`.

---

## 3. Phần cần thống nhất với thành viên khác

### 3.1 Prompt: cần Khánh thêm chỗ nhập
`UserModel.prompts` đã có và màn chi tiết đã hiển thị, nhưng **onboarding và edit profile chưa có ô nhập prompt**. User thật sẽ không bao giờ có prompt. Huy và Khánh cần thống nhất: Khánh thêm bước nhập prompt, dùng đúng format `{question, answer}` trong `ProfilePrompt`.

### 3.2 Màn "Ai đã thích bạn" bị trùng với Dũng
Huy có `who_liked_you_screen.dart` (route `/likes`, **chưa làm mờ ảnh**, `kBlurLikedYou = false`). Dũng có `who_liked_me_screen.dart` làm đầy đủ. Màn này thuộc **module 4 của Dũng**, nên khi merge Huy nên **bỏ màn của mình**, giữ lại icon ♥ trên AppBar trỏ sang màn của Dũng.

### 3.3 Popup match bị trùng với Đức Anh
`_showMatchDialog` là popup riêng của Huy. Đức Anh đã có `match_celebration_screen.dart` (animation, ảnh hai bên). Khi merge nên thay bằng `showMatchCelebration(...)` của Đức Anh.

### 3.4 Ghost mode của Sơn
Sơn lưu `ghost_mode: true` vào `users`. Discovery của Huy **chưa bỏ qua những người này**, nên người đang ẩn danh vẫn hiện trong thẻ quẹt. Cần thêm `if (data['ghost_mode'] == true) continue;` trong `getDiscoveryPage`.

### 3.5 Rewind của Dũng
Khi Dũng hoàn tác (xóa swipe), id người đó vẫn nằm trong `_excluded` của Huy, nên phải đợi lần `reload()` sau mới hiện lại. Cần một hàm ví dụ `DiscoveryViewModel.restore(userId)` để Dũng gọi sau khi rewind.

### 3.6 Huy sửa file của người khác
Để hỗ trợ dark mode, Huy đã sửa màu trong `login_screen.dart`, `register_screen.dart`, `onboarding_screen.dart`, `edit_profile_screen.dart` (của Khánh) và `chat_screen.dart`, `match_list_screen.dart` (của Đức Anh). Đức Anh đã viết lại gần hết 2 file chat, nên **chắc chắn conflict**. Khi merge nên giữ bản của Đức Anh rồi áp lại phần màu.

---

## 4. Việc nên làm thêm (không bắt buộc)

- Viết test cho phần lọc trong `getDiscoveryPage` (tuổi, giới tính, block, khoảng cách, sở thích). Có thể tách phần lọc thành hàm thuần để test không cần Firestore.
- Nút "Tạo 30 user giả" chỉ hiện ở bản debug (`kDebugMode`), vậy là ổn. Cần nhớ xóa dữ liệu `seed_*` trên Firestore trước khi nộp bài.

## 5. Checklist cho Huy

- [x] Sửa lỗi treo loading (2.1)
- [x] Báo lỗi khi tải thêm thất bại (2.2)
- [x] Báo khi không có vị trí; xử lý người không có `location` (2.3) — người không có vị trí bị ẩn
- [x] Chip sở thích có tác dụng mà không cần bật công tắc (2.4)
- [x] Sửa badge số tin chưa đọc (2.5) — `unreadCountProvider`
- [x] Reset `_consumed` trong `ref.listen` (2.6)
- [x] Bỏ qua user `ghost_mode` (3.4)
- [ ] Bỏ màn Who Liked You của mình, dùng màn của Dũng (3.2) — làm khi merge
- [ ] Dùng `showMatchCelebration` của Đức Anh (3.3) — làm khi merge
- [ ] Thống nhất với Khánh về ô nhập prompt (3.1)
- [x] Thêm hàm để Dũng gọi sau khi rewind (3.5) — `DiscoveryViewModel.restore(userId)`
- [x] Viết thêm test cho logic lọc — `passesDiscoveryFilter` (9 test)
