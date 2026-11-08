# DatingLy push server

Gửi **thông báo đẩy (FCM)** cho người dùng khi có sự kiện, kể cả lúc app đã tắt.
Không cần gói Blaze: dùng `firebase-admin` + service account, chạy bằng Node.js.

| Sự kiện (Firestore) | Người nhận | Thông báo |
|---|---|---|
| `swipes` like / super_like | người được thích | "Có người vừa thích bạn 💖" (ẩn danh, mở `/likes`) |
| `matches` mới | người đã thích trước | "Tương hợp mới! 🎉 Bạn và X đã thích nhau…" (mở `/chat/{id}`) |
| `messages` mới | người còn lại trong match | Tên người gửi + nội dung (mở `/chat/{id}`) |

Chỉ các sự kiện xảy ra **sau khi server khởi động** mới được gửi.

## Cài đặt (một lần)

1. Cài Node.js >= 18.
2. Firebase Console → **Project settings → Service accounts → Generate new private key**.
   Lưu file thành `tools/push_server/serviceAccountKey.json`.
   **Không commit và không chia sẻ file này** (đã có trong `.gitignore`); ai có nó đều toàn quyền project.
3. Trong thư mục này:
   ```
   npm install
   npm test       # kiểm tra phần tạo nội dung thông báo (không cần khóa)
   ```

## Chạy

```
npm start
```

Server phải **chạy liên tục** thì mới gửi được thông báo (ví dụ để mở trên laptop khi demo).
Log mẫu: `[sent] message -> <uid>: Lan`.

Có thể đặt khóa ở chỗ khác bằng biến môi trường `GOOGLE_APPLICATION_CREDENTIALS`.

## Điều kiện để máy nhận được thông báo

- Đã đăng nhập ít nhất một lần trong app (app lưu `fcm_token` vào `users/{uid}`).
- Đã cấp quyền thông báo cho app (Android 13+).
- Máy ảo phải có Google Play services.
- Chạy lại app sau khi cập nhật code này để tạo channel `datingly_main_channel`.
