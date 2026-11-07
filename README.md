# DatingLy — Ứng dụng Hẹn hò Trực tuyến (PRM393)

> **Môn học**: PRM393 — Lập trình Di động nâng cao (FPT University)  
> **Nhóm thực hiện**: Group 1 (SE1942-JS)  
> **Kiến trúc**: MVVM (Model - View - ViewModel) + Riverpod State Management  

---

## 🚀 Giới thiệu & Công nghệ sử dụng

DatingLy là ứng dụng hẹn hò trực tuyến hiện đại được xây dựng bằng Flutter, đáp ứng đầy đủ các tiêu chuẩn kỹ thuật của môn học PRM393:

| Yêu cầu kỹ thuật | Giải pháp triển khai | Thành phần phụ trách |
|---|---|---|
| **Đăng nhập & Xác thực** | Firebase Authentication (Email/Password & Phone OTP) | `auth_repository.dart`, `auth_view_model.dart` |
| **Thông báo đẩy (Notification)** | Firebase Cloud Messaging (FCM) + `flutter_local_notifications` | `notification_repository.dart`, `notification_bootstrap.dart` |
| **Mô hình lập trình** | Chuẩn **MVVM** (Phân tách độc lập View – ViewModel – Repository – Model) | `lib/UI/Views`, `lib/UI/ViewModels`, `lib/data/` |
| **Quản lý trạng thái** | Flutter Riverpod (`StateNotifierProvider`, `StreamProvider`, `FutureProvider`) | `app_providers.dart`, `*view_model.dart` |
| **Lưu trữ dữ liệu đám mây** | Cloud Firestore (`users`, `swipes`, `matches`, `messages`) & Firebase Storage (Ảnh hồ sơ) | `data_helper.dart`, `user_repository.dart` |
| **Lưu trữ cấu hình cục bộ** | `SharedPreferences` (`isFirstTimeUser`, `onboardingCompleted`, cache hồ sơ, dark mode, filters) | `setting_repository.dart`, `preferences_view_model.dart` |
| **Trợ lý AI Hẹn hò** | Google Gemini Generative AI (Gợi ý câu mở lời tán tỉnh, câu chuyện theo bio/tags) | `ai_repository.dart` |
| **Định vị & Khoảng cách** | GPS Geolocator + Công thức Haversine tính khoảng cách hẹn hò (km) | `location_repository.dart`, `geo_utils.dart` |

---

## 📌 Module 1: Onboarding & Quản lý Hồ sơ Cá nhân (Khánh)

Module cốt lõi phụ trách luồng đăng nhập, khởi tạo hồ sơ và quản lý thông tin cá nhân:

### 1. Phone/Email Auth & OTP Screen
- **Đăng nhập/Đăng ký Email & Password**: Kiểm tra hợp lệ dữ liệu đầu vào, xử lý ngoại lệ `FirebaseAuthException` hiển thị thông báo thân thiện.
- **Đăng nhập qua Số điện thoại (Phone Auth)**: Tích hợp xác thực OTP Firebase, có bộ đếm ngược thời gian resend OTP (60s timer).
- **Auto-routing theo Auth State**: Lắng nghe `authStateChanges` qua `StreamProvider`, tự động điều hướng sang màn hình Onboarding hoặc Discovery tùy theo trạng thái hoàn thành hồ sơ.

### 2. Profile Setup & Media Stepper Screen
- **Form nhập liệu nhiều bước (Stepper)**: 
  - Bước 1: Họ tên, Ngày sinh (xác thực tuổi hợp lệ $\ge 18$).
  - Bước 2: Giới tính & Định hướng hẹn hò (Nghiêm túc, Tìm hiểu lâu dài, Bạn bè, Để xem thế nào...).
  - Bước 3: Tags sở thích phân theo danh mục (Âm nhạc, Thể thao, Ẩm thực, Phong cách, Giải trí).
  - Bước 4: Câu hỏi Prompt tương tác ("Điều khiến mình cười nhất", "Buổi hẹn đầu tiên"...).
- **Quản lý Media & Ảnh đại diện**:
  - Chọn nhiều ảnh đại diện, hỗ trợ sắp xếp thứ tự ưu tiên ảnh thẻ.
  - **Interactive Crop Dialog**: Hộp thoại căn chỉnh, phóng to thu nhỏ và cắt ảnh chuẩn tỉ lệ hẹn hò $3:4$.
  - **Image Compression**: Nén dữ liệu ảnh tối ưu trước khi đẩy lên Firebase Storage.

### 3. Edit Profile & Tag Selector Screen
- **Chỉnh sửa Bio**: Hỗ trợ đếm số lượng ký tự tối đa (500 ký tự) và chip gợi ý nhanh (Quick Prompts).
- **Cập nhật danh sách ảnh**: Thêm/xóa/đổi vị trí ảnh đại diện, ảnh đầu tiên tự động làm Avatar chính.
- **Tag Selector**: Giao diện chọn lại tags sở thích theo từng danh mục trực quan.
- **Live Preview Thẻ Hồ sơ**: Xem trước tức thời thẻ hồ sơ swipe card đúng như người khác nhìn thấy.

### 4. Dữ liệu & Local Storage
- **SharedPreferences**: Lưu cờ `isFirstTimeUser`, `onboardingCompleted`, và cache hồ sơ người dùng cơ bản (`cachedUserProfile`) để tải nhanh offline.
- **Firestore `users` collection**: Cập nhật và đồng bộ hai chiều thời gian thực thông tin hồ sơ người dùng.

---

## 📂 Cấu trúc Thư mục Dự án (PRM393 MVVM Pattern)

Toàn bộ mã nguồn được tổ chức tinh gọn trong hai thư mục chính **`data`** và **`UI`**, không dùng `core` hoặc `services`:

```
lib/
├── data/
│   ├── models/                             # Tầng Model dữ liệu & Domain Constants
│   │   ├── discovery_filter.dart           # Model bộ lọc tìm kiếm (khoảng cách, độ tuổi, giới tính)
│   │   ├── match_model.dart                # Model dữ liệu cặp đôi tương hợp
│   │   ├── message_model.dart              # Model tin nhắn văn bản real-time
│   │   ├── profile_constants.dart          # Hằng số danh mục sở thích, định hướng hẹn hò, prompts
│   │   └── user_model.dart                 # Model người dùng, parse Firestore & JSON caching
│   │
│   └── repositories/                       # Tầng Repository & Data Access (kết nối Firebase/Local)
│       ├── ai_repository.dart              # Xử lý gợi ý tin nhắn qua Google Gemini AI
│       ├── app_providers.dart              # Khai báo Riverpod Providers cho các Repository
│       ├── auth_repository.dart            # Nghiệp vụ xác thực Firebase Auth (Email & Phone OTP)
│       ├── chat_repository.dart            # Quản lý tin nhắn và phòng chat trên Firestore
│       ├── data_helper.dart                # Singleton giữ kết nối Firestore, Auth và Storage
│       ├── discovery_repository.dart       # Quản lý quẹt thẻ, matching và query thẻ hẹn hò
│       ├── geo_utils.dart                  # Hàm tính cự ly khoảng cách Haversine (km)
│       ├── location_repository.dart        # Quản lý quyền và lấy toạ độ GPS (Geolocator)
│       ├── notification_repository.dart    # Cấu hình FCM Token, Local Notifications & background
│       ├── seed_repository.dart            # Tạo/xóa 30 hồ sơ mock dữ liệu phục vụ test
│       ├── setting_repository.dart         # Quản lý SharedPreferences (Cấu hình & Cache user)
│       └── user_repository.dart            # CRUD hồ sơ người dùng và upload ảnh lên Firebase Storage
│
├── UI/
│   ├── app_colors.dart                     # Bảng màu chuẩn thương hiệu DatingLy
│   ├── app_router.dart                     # Cấu hình định tuyến màn hình GoRouter
│   ├── app_theme.dart                      # Cấu hình ThemeData (Light / Dark mode)
│   │
│   ├── ViewModels/                         # Tầng ViewModel (Quản lý trạng thái giao diện Riverpod)
│   │   ├── auth_view_model.dart            # StateNotifier đăng nhập, đăng ký, OTP và timer
│   │   ├── chat_view_model.dart            # Quản lý tin nhắn và danh sách tương hợp
│   │   ├── discovery_view_model.dart       # Quản lý hàng đợi thẻ quẹt (Swipes) và bộ lọc
│   │   ├── notification_bootstrap.dart     # Listener lắng nghe và kích hoạt thông báo
│   │   ├── preferences_view_model.dart     # Quản lý trạng thái theme và cấu hình chung
│   │   └── profile_view_model.dart         # Quản lý cập nhật hồ sơ cá nhân và ảnh đại diện
│   │
│   └── Views/                              # Tầng View (Giao diện hiển thị)
│       ├── Screen/                         # Màn hình ứng dụng
│       │   ├── login_screen.dart           # Đăng nhập Email & Phone OTP
│       │   ├── register_screen.dart        # Đăng ký tài khoản mới
│       │   ├── onboarding_screen.dart      # Stepper nhập hồ sơ nhiều bước
│       │   ├── profile_screen.dart         # Xem hồ sơ cá nhân và cài đặt
│       │   ├── edit_profile_screen.dart    # Chỉnh sửa bio, chọn tags, cập nhật ảnh
│       │   ├── view_profile_screen.dart    # Xem chi tiết hồ sơ đối phương
│       │   ├── discovery_screen.dart       # Màn hình quẹt thẻ hẹn hò chính
│       │   ├── discovery_filter_screen.dart# Màn hình tùy chỉnh bộ lọc tìm kiếm
│       │   ├── who_liked_you_screen.dart   # Danh sách những người đã thích bạn
│       │   ├── match_list_screen.dart      # Danh sách tương hợp và hội thoại
│       │   ├── chat_screen.dart            # Phòng nhắn tin trực tiếp tích hợp gợi ý AI
│       │   └── mini_game_screen.dart       # Minigame hỏi nhanh đáp gọn phá băng
│       │
│       └── Widget/                         # Các widget tái sử dụng
│           ├── app_branding_widget.dart    # Logo, biểu tượng và slogan thương hiệu
│           ├── crop_image_dialog_widget.dart# Dialog tương tác cắt và căn chỉnh ảnh
│           ├── current_dialog_widget.dart  # Dialog thông báo và xác nhận dùng chung
│           └── image_crop_compress_helper.dart # Helper xử lý nén và cắt ảnh
│
├── firebase_options.dart                   # Cấu hình tự động sinh từ Firebase CLI
└── main.dart                               # Điểm khởi động ứng dụng với ProviderScope
```

---

## 🔄 Luồng Dữ liệu MVVM (Data Flow)

$$\begin{matrix}
\mathbf{View} & \longleftrightarrow & \mathbf{ViewModel} & \longleftrightarrow & \mathbf{Repository} & \longleftrightarrow & \mathbf{Data\ Source} \\
\text{(Screen / Widget)} & & \text{(Riverpod Notifiers)} & & \text{(Business Data Logic)} & & \text{(Firestore / SharedPreferences)}
\end{matrix}$$

1. **View** (`lib/UI/Views/`): Chỉ chịu trách nhiệm render giao diện, bắt sự kiện người dùng và gọi các hàm trong `ViewModel`.
2. **ViewModel** (`lib/UI/ViewModels/`): Chứa state của màn hình, gọi `Repository` tương ứng để xử lý nghiệp vụ và emit state mới cho `View`.
3. **Repository** (`lib/data/repositories/`): Trung gian điều phối dữ liệu từ `DataHelper` (Firestore, Firebase Auth, Firebase Storage) hoặc `SettingRepository` (SharedPreferences).
4. **Model** (`lib/data/models/`): Định nghĩa khuôn mẫu dữ liệu thuần túy (Immutable objects, JSON serialization).

---

## 🛠️ Hướng dẫn Cài đặt & Chạy ứng dụng

### 1. Chuẩn bị môi trường
- Flutter SDK $\ge 3.11.4$
- Android Studio / VS Code
- Tài khoản Firebase đã bật các dịch vụ:
  - **Authentication**: Bật *Email/Password* và *Phone*.
  - **Cloud Firestore**: Khởi tạo database chế độ test/production.
  - **Firebase Storage**: Khởi tạo bucket lưu trữ ảnh.
  - **Cloud Messaging (FCM)**: Đăng ký ứng dụng Android/iOS.

### 2. Cài đặt dependencies
```bash
flutter pub get
```

### 3. Kiểm tra chất lượng mã nguồn & Unit Tests
```bash
# Phân tích tĩnh mã nguồn (Đảm bảo 0 issues)
flutter analyze

# Chạy toàn bộ Unit Tests kiểm tra Onboarding, Profile Caching & Discovery Filter
flutter test
```

### 4. Chạy ứng dụng
```bash
# Chạy app thông thường
flutter run

# Chạy app có tích hợp Google Gemini AI gợi ý tin nhắn (Khuyên dùng)
flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
```

> [!NOTE]
> - Tính năng Push Notification hoạt động tốt nhất trên thiết bị thật Android hoặc iOS.
> - Có thể vào màn hình **Bộ lọc tìm kiếm (Discovery Filter)** $\rightarrow$ chọn **"Tạo 30 user giả lập"** để nạp dữ liệu mẫu trải nghiệm quẹt thẻ ngay lập tức mà không cần tạo nhiều tài khoản.
