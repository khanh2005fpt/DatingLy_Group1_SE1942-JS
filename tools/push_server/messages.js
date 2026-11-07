'use strict';

// Tạo nội dung thông báo cho từng sự kiện. Thuần hàm (không phụ thuộc Firebase) nên test được.

const CHANNEL_ID = 'datingly_main_channel'; // phải trùng channel app tạo trong NotificationRepository

function truncate(text, max = 120) {
  const t = String(text ?? '').trim();
  return t.length > max ? `${t.slice(0, max - 1)}…` : t;
}

/** Ai đó thích / super like mình (chưa match): không lộ danh tính, giống màn "Ai đã thích bạn". */
function likeNotification(action) {
  const superLike = action === 'super_like';
  return {
    type: 'like',
    title: superLike ? 'Bạn nhận được Super Like ⭐' : 'Có người vừa thích bạn 💖',
    body: 'Mở DatingLy để xem ai đã thích bạn.',
    route: '/likes',
  };
}

/** Match mới, gửi cho người đã thích trước (người quẹt sau thấy match ngay trong app). */
function matchNotification(matchId, otherName) {
  const name = (otherName || '').trim() || 'Ai đó';
  return {
    type: 'match',
    title: 'Tương hợp mới! 🎉',
    body: `Bạn và ${name} đã thích nhau. Nhắn tin ngay nhé!`,
    route: `/chat/${matchId}`,
  };
}

/** Tin nhắn mới trong một cuộc trò chuyện. */
function messageNotification(matchId, senderName, messageType, content) {
  const name = (senderName || '').trim() || 'Tin nhắn mới';
  let body;
  if (messageType === 'image') body = 'Đã gửi một ảnh 📷';
  else body = truncate(content) || 'Bạn có tin nhắn mới';
  return {
    type: 'message',
    title: name,
    body,
    route: `/chat/${matchId}`,
  };
}

/** Chuyển nội dung thông báo thành payload cho admin.messaging().send(). */
function toFcmMessage(token, n) {
  return {
    token,
    notification: { title: n.title, body: n.body },
    // App đọc data.route để mở đúng màn hình, data.type để tránh hiện trùng khi đang mở app.
    data: { type: n.type, route: n.route },
    android: {
      priority: 'high',
      notification: { channelId: CHANNEL_ID },
    },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

/** Token đã hỏng/không còn đăng ký: nên xóa khỏi hồ sơ người dùng. */
function isDeadTokenError(err) {
  const code = err && err.code;
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token'
  );
}

module.exports = {
  CHANNEL_ID,
  truncate,
  likeNotification,
  matchNotification,
  messageNotification,
  toFcmMessage,
  isDeadTokenError,
};
