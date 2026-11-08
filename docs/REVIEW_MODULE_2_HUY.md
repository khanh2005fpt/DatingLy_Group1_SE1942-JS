v  # Review Module 2: Khám phá & Quẹt thẻ (Huy)

> Nhánh: `feature/discovery-swipe` · commit `3c30483` (21/10/2026, nqhuyyy11)
> Cách làm: đọc toàn bộ code thay đổi so với `main` và đối chiếu với file phân công. **Chưa chạy app, chưa chạy test** (máy kiểm tra không cài Flutter).

## 1. Đối chiếu yêu cầu

| Yêu cầu | Trạng thái | Code |
| --- | --- | --- |
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

## 5. Checklist cho Huy

- [x] Sửa lỗi treo loading (2.1)
- [x] Báo lỗi khi tải thêm thất bại (2.2)
- [x] Báo khi không có vị trí; xử lý người không có `location` (2.3) — người không có vị trí bị ẩn
- [x] Chip sở thích có tác dụng mà không cần bật công tắc (2.4)
- [x] Sửa badge số tin chưa đọc (2.5) — `unreadCountProvider`
- [x] Reset `_consumed` trong `ref.listen` (2.6)
- [x] Bỏ qua user `ghost_mode` (3.4)
- [ ] Bỏ màn Who Liked You của mình, dùng màn của Dũng (3.2) — chờ `module_4` của Dũng merge vào dev
- [x] Dùng `showMatchCelebration` của Đức Anh (3.3) — `_showMatchDialog` gọi `showMatchCelebration`
- [x] Thống nhất với Khánh về ô nhập prompt (3.1) — `ProfilePromptsEditor` trong onboarding và edit profile
- [x] Thêm hàm để Dũng gọi sau khi rewind (3.5) — `DiscoveryViewModel.restore(userId)`
- [x] Viết thêm test cho logic lọc — `passesDiscoveryFilter` (9 test)

---

## 6. Giải thích các khái niệm trong review

### 6.1 Phần yêu cầu

- **AppinioSwiper (`maxAngle: 15`)**: package tạo chồng thẻ quẹt kiểu Tinder. `maxAngle` là góc nghiêng tối đa khi kéo thẻ (15°). Package lo phần hiệu ứng và báo hướng quẹt (trái / phải / lên).
- **Lazy-load / pagination**: không tải hết user một lần mà tải từng "trang", gần hết thẻ mới tải tiếp.
  - `startAfterDocument(lastDoc)`: Firestore lấy tiếp từ sau document cuối của trang trước, không bị trùng.
  - "Còn ≤ 5 thẻ thì tải trước" là **prefetch**, để người dùng quẹt không bị khựng.
  - `hasMore`: cờ báo trên server còn dữ liệu hay không.
- **Geolocator + Haversine**: `geolocator` lấy tọa độ GPS của máy. **Haversine** là công thức tính khoảng cách (km) giữa hai tọa độ trên mặt cầu Trái Đất (`haversineKm` trong `geo_utils.dart`). Dùng để hiện "Cách bạn X km" và để lọc theo slider khoảng cách.
- **Lọc trên Firestore và lọc ở client**:
  - Tuổi (`where age` + `orderBy age`) lọc **trên server**, nên Firestore chỉ trả về người đúng tuổi, đỡ tốn lượt đọc.
  - Giới tính, khoảng cách, sở thích, block, ghost mode lọc **trên máy** sau khi tải về, vì Firestore không cho nhiều điều kiện range trên nhiều field và không tự tính được khoảng cách. Tất cả nằm trong `passesDiscoveryFilter` (`discovery_repository.dart`).
- **Prompt (`ProfilePrompt {question, answer}`)**: câu hỏi gợi chuyện trên hồ sơ, giống Hinge. Ví dụ: "Cuối tuần lý tưởng của tôi là…" → "…đi phượt Đà Lạt". Làm hồ sơ có cá tính hơn chỉ ảnh + bio.
- **Loại trừ người đã quẹt / đã block**: `getExcludedUserIds` gom ID những người mình đã quẹt và những người có quan hệ block, để họ không hiện lại. "Cả hai chiều": mình block họ **hoặc** họ block mình thì đều không thấy nhau.
- **Collection `swipes`, doc id cố định**: mỗi lần quẹt ghi doc id `swiperId_swipedId`. Quẹt lại cùng người thì chỉ ghi đè, không tạo bản ghi mới. Match id cũng cố định (ghép 2 id theo thứ tự), nên hai người Like nhau gần như cùng lúc vẫn chỉ tạo **một** match.
- **SharedPreferences**: kho key-value nhỏ lưu trên máy. Dùng để nhớ filter (`min_age`, `max_age`, `max_distance`, `interested_in`…), tắt app mở lại vẫn giữ. Không lên server, mỗi máy một bản.
- **Unit test**: code tự kiểm tra hàm thuần (không cần UI, Firestore), ví dụ haversine tính đúng không, filter loại đúng người không. Chạy bằng `flutter test`.

### 6.2 Phần lỗi

- **Treo loading (2.1)**: state không tự thoát ra được. Màn hình ở trạng thái "chờ tải" (`exhausted && hasMore`), nhưng thứ duy nhất kích hoạt tải là quẹt thẻ, mà lúc đó không còn thẻ.
  - Cách 1: `loadMore()` tự gọi lại nếu trang vừa tải bị lọc sạch (có giới hạn số lần để không lặp vô hạn).
  - Cách 2: `addPostFrameCallback` hẹn chạy code **ngay sau khi frame hiện tại vẽ xong**. Không được đổi state ngay trong `build()` (Flutter báo lỗi), nên phải hẹn sang sau frame.
- **`errorMessage` và `hasMore: false` (2.2)**: "hết dữ liệu" khác "tải lỗi". Lẫn hai cái thì người mất mạng tưởng hết người để quẹt. Có `errorMessage` thì màn hình mới hiện được nút "Thử lại".
- **Lọc khoảng cách không chặt (2.3)**: trường hợp thiếu dữ liệu (mình không có GPS, hoặc người kia không có `location`). Code cũ bỏ qua bộ lọc nên đặt 1 km vẫn thấy người ở xa. Đã sửa: người không có vị trí bị ẩn.
- **Badge (2.5)**: số đỏ nhỏ trên icon chat. Code cũ đếm **số match** thay vì **số tin chưa đọc**. `unreadCountProvider` giờ cộng `unreadCount` của từng match.
- **`ref.listen` và gán biến trong `build` (2.6)**:
  - `build()` có thể bị Flutter gọi rất nhiều lần bất cứ lúc nào, nên trong đó chỉ nên **vẽ UI**, không đổi biến (side effect).
  - `ref.listen(provider, (prev, next) {...})` của Riverpod chỉ chạy callback **khi giá trị thay đổi**. Đây là chỗ đúng để reset `_consumed`.
- **Riverpod / Provider / ViewModel (nền tảng)**:
  - **ViewModel** (`DiscoveryViewModel`) giữ state của màn hình (danh sách thẻ, đang tải, lỗi…) và logic. UI chỉ đọc state rồi vẽ.
  - **Provider** là cách Riverpod đưa ViewModel / dữ liệu tới widget. `ref.watch` theo dõi và vẽ lại khi đổi; `ref.read` đọc một lần (dùng khi bấm nút).
  - File `.g.dart` là code **tự sinh** bởi `build_runner` từ annotation `@riverpod`. Không sửa tay.

### 6.3 Phần liên quan thành viên khác

- **Ghost mode (Sơn)**: chế độ ẩn danh, bật lên thì không xuất hiện trong Discovery của ai. Cờ `ghost_mode: true` trong doc `users`, đã lọc trong `passesDiscoveryFilter`.
- **Rewind (Dũng)**: hoàn tác lần quẹt vừa rồi (xóa doc swipe). ViewModel của Huy cache `_excluded` trong bộ nhớ, nên cần `DiscoveryViewModel.restore(userId)` để bỏ ID đó khỏi danh sách loại trừ và đưa thẻ trở lại ngay.
- **Who Liked You và blur (Dũng)**: màn liệt kê người đã Like mình. Làm mờ ảnh là tính năng premium kiểu Tinder (trả phí mới xem mặt). `kBlurLikedYou` là công tắc bật/tắt mờ trong bản của Huy. Màn này trùng với Dũng nên sẽ bỏ khi merge.
- **Match celebration (Đức Anh)**: popup "It's a Match!" có animation. `showMatchCelebration` là hàm dùng chung, Discovery giờ gọi hàm này thay cho popup riêng.
- **Merge conflict (3.6)**: hai người cùng sửa một đoạn trong cùng file thì git không tự chọn được, bắt mình quyết. Nên giữ bản của Đức Anh rồi áp lại phần màu dark mode.
