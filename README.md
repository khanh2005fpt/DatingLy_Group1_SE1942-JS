# DatingLy

Ứng dụng hẹn hò Flutter – môn PRM393.

## Công nghệ
| Yêu cầu | Giải pháp |
|---|---|
| Đăng nhập | Firebase Authentication (Email/Password) |
| Notification | Firebase Cloud Messaging + flutter_local_notifications |
| Kiến trúc | MVVM |
| Quản lý trạng thái | Riverpod (`Notifier`, `NotifierProvider`, `StreamProvider`) |
| Lưu dữ liệu | Cloud Firestore (users, swipes, matches, messages), Firebase Storage (ảnh) |
| Lưu cấu hình | SharedPreferences (dark mode, bật/tắt thông báo, tab giới tính, onboarding, FCM token) |

## Cấu trúc
```
lib/
├── core/            # providers, router, theme, widgets dùng chung
├── data/
│   ├── models/      # UserModel, MatchModel, MessageModel
│   └── services/    # Firebase Auth/Firestore/Storage, Notification, Preferences, AI
└── features/
    ├── auth/        # screens + viewmodels
    ├── discovery/
    ├── chat/
    └── profile/
```
View (screens) chỉ gọi ViewModel; ViewModel gọi Service; Service làm việc với Firebase/SharedPreferences.

## Chạy app
1. Bật Email/Password (Authentication), tạo Firestore database, (tuỳ chọn) Storage trên Firebase Console.
2. Cấu hình Firebase: `flutterfire configure --project=<project-id>`
3. `flutter pub get`
4. `flutter run` (gợi ý AI cần: `--dart-define=GEMINI_API_KEY=<key>`)

Thông báo match/tin nhắn mới hoạt động trên Android/iOS (không hỗ trợ web).
"# DatingLy_Group1_SE1942-JS" 
"# DatingLy_Group1_SE1942-JS" 
