# Luồng hoạt động của DatingLy

Tài liệu mô tả luồng người dùng chính và ranh giới giữa 5 module, để cả nhóm thống nhất khi code.

## 1. Luồng chính

```
Mở app
  │
  ├─ chưa đăng nhập ─► /login ──► /register
  │                                  │ signUp(): tạo users/{uid} rỗng
  │                                  ▼
  │                             /onboarding
  │                                  │ nhập hồ sơ + upload ảnh → lưu users/{uid}
  │                                  ▼
  └─ đã đăng nhập ───────────► /discovery  (quẹt thẻ)
                                     │
                                     │ mỗi lần quẹt: ghi swipes/{me}_{target}
                                     │ đối phương đã like mình chưa?
                                     ├─ chưa ─► thẻ kế tiếp
                                     └─ rồi  ─► tạo matches ─► popup "It's a Match"
                                                      │
                                         ┌────────────┴────────────┐
                                    "Nhắn tin ngay"         "Tiếp tục quẹt"
                                         ▼                         ▼
                                   /chat/{matchId}            /discovery
```

Các màn hình phụ đi ra từ Discovery:

| Từ Discovery | Tới | Ghi chú |
|---|---|---|
| Icon filter | Filter & Preferences | lưu SharedPreferences, Discovery reload khi áp dụng |
| Tap thẻ | Deep View profile | xem album, bio, prompts, sở thích chung |
| Icon chat | `/matches` | danh sách match + hội thoại |
| Icon profile | `/profile` | xem / sửa hồ sơ, cài đặt, đăng xuất |

## 2. Dữ liệu đi qua các module

| Collection (Firestore) | Ai ghi | Ai đọc |
|---|---|---|
| `users` | Khánh (onboarding, edit profile); Huy ghi thêm `location` | Huy (discovery, deep view), Đức Anh (chat header) |
| `swipes` | Huy | Huy (loại người đã quẹt), Dũng (Who Liked You, History/Rewind) |
| `matches` | Huy tạo khi hai bên like; Đức Anh quản lý sau đó | Đức Anh (list, chat), Dũng (thông báo match) |
| `messages` | Đức Anh | Đức Anh, Sơn (media gallery) |
| `reports`, `blocked_users` | Sơn | Huy (loại người bị chặn khỏi Discovery) |

### Hợp đồng giữa các module

- **`swipes/{myId}_{targetId}`**: `swiper_id`, `swiped_id`, `action` (`like` | `nope` | `super_like`), `created_at`. Không đổi tên field khi chưa báo Dũng.
- **Match**: Huy trả `matchId` sau khi quẹt. Popup match do Đức Anh làm; Huy chỉ gọi tới nó.
- **Block**: dùng mảng `blocked_users` của Sơn. Huy chỉ đọc để loại trừ, không tạo collection riêng.
- **`interested_in`**: Khánh nhập "định hướng" khi onboarding, Huy lưu cùng tên ở filter. Giá trị: `Nữ` | `Nam` | `Khác` | `all`.
- **Local**: SharedPreferences (cấu hình) và SQLite (cache tin nhắn, thông báo, lịch sử) bị xóa khi Logout (Sơn).

## 3. Phân công

| Module | Người | Khâu trong luồng |
|---|---|---|
| 1. Onboarding & hồ sơ | Khánh | Đăng nhập/đăng ký, onboarding, sửa hồ sơ |
| 2. Khám phá & quẹt thẻ | Huy | Discovery, filter, deep view |
| 3. Match & Chat | Đức Anh | Popup match, danh sách match, chat realtime |
| 4. Thông báo & nhật ký | Dũng | FCM, Notification Center, Who Liked You, Rewind |
| 5. An toàn & cài đặt | Sơn | Settings, block/report, media gallery, clear cache |

## 4. Vấn đề đã phát hiện ở luồng hiện tại

Phát hiện khi đối chiếu code với luồng ở mục 1. Cả hai nằm ở module 1 (Khánh).

### 4.1 Ảnh upload ở onboarding bị ghi đè thành rỗng

- `onboarding_screen.dart` upload ảnh, `uploadAvatar` / `uploadPhoto` ghi `avatar_urls` lên Firestore.
- Ngay sau đó `AuthViewModel.updateInitialProfile` tạo `UserModel` với `avatarUrls: state.userModel?.avatarUrls`, giá trị này lấy từ lúc `signUp` nên rỗng. `toMap()` luôn ghi `avatar_urls`, nên ảnh vừa upload bị xóa.
- `created_at` cũng bị ghi đè bằng `serverTimestamp` mới.
- **Hướng sửa:** đọc profile hiện có từ Firestore rồi `copyWith(...)` (như `ProfileViewModel.updateProfile` đang làm), hoặc truyền `allUrls` vào `updateInitialProfile`.

### 4.2 Thoát giữa chừng onboarding thì lần sau bị bỏ qua

- `initialLocation` là `/login`, `redirect` thấy đã đăng nhập thì đẩy thẳng sang `/discovery`.
- Kiểm tra `fullName` rỗng chỉ nằm trong `_handleLogin`, nên không áp dụng khi mở lại app.
- Kết quả: user vào Discovery với hồ sơ trống.
- **Hướng sửa:** đưa điều kiện "hồ sơ chưa hoàn tất → `/onboarding`" vào `redirect` của router, hoặc đọc cờ `onboardingCompleted` từ SharedPreferences / Firestore.

### 4.3 Người chưa có hồ sơ xuất hiện trong thẻ quẹt (module Huy)

`getDiscoveryUsers` không lọc user có `full_name` rỗng. Sẽ được xử lý khi viết lại `getDiscoveryPage` trong spec Discovery (`docs/specs/discovery-swipe-feature-spec.md`).
