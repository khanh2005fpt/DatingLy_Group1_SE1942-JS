'use strict';

/**
 * DatingLy push server: lắng nghe Firestore và gửi thông báo đẩy (FCM) cho người nhận.
 * Chạy bằng `node index.js`, KHÔNG cần gói Blaze (dùng firebase-admin với service account).
 *
 * Sự kiện xử lý:
 *   swipes   -> like / super_like : báo cho người được thích (ẩn danh)
 *   matches  -> match mới         : báo cho người đã thích trước
 *   messages -> tin nhắn mới      : báo cho người còn lại trong cuộc trò chuyện
 */

const path = require('path');
const fs = require('fs');
const admin = require('firebase-admin');
const {
  likeNotification,
  matchNotification,
  messageNotification,
  toFcmMessage,
  isDeadTokenError,
} = require('./messages');

const keyPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, 'serviceAccountKey.json');

if (!fs.existsSync(keyPath)) {
  console.error(
    `Không tìm thấy service account tại: ${keyPath}\n` +
      'Tải khóa ở Firebase Console > Project settings > Service accounts > Generate new private key,\n' +
      'lưu thành tools/push_server/serviceAccountKey.json (file này đã được .gitignore, KHÔNG commit).',
  );
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db = admin.firestore();
const messaging = admin.messaging();

// Chỉ xử lý sự kiện xảy ra SAU khi server khởi động, tránh gửi lại dữ liệu cũ.
const startedAt = admin.firestore.Timestamp.now();

// Chống gửi trùng khi Firestore báo lại cùng một thay đổi.
const handled = new Set();
function firstTime(key) {
  if (handled.has(key)) return false;
  handled.add(key);
  if (handled.size > 5000) handled.delete(handled.values().next().value);
  return true;
}

async function getUser(uid) {
  const snap = await db.collection('users').doc(uid).get();
  return snap.exists ? snap.data() : null;
}

async function pushToUser(uid, notification) {
  const user = await getUser(uid);
  const token = user && user.fcm_token;
  if (!token) {
    console.log(`[skip] ${uid} chưa có fcm_token (${notification.type})`);
    return;
  }
  try {
    await messaging.send(toFcmMessage(token, notification));
    console.log(`[sent] ${notification.type} -> ${uid}: ${notification.title}`);
  } catch (err) {
    if (isDeadTokenError(err)) {
      console.warn(`[dead token] xóa fcm_token của ${uid}`);
      await db
        .collection('users')
        .doc(uid)
        .update({ fcm_token: admin.firestore.FieldValue.delete() })
        .catch(() => {});
    } else {
      console.error(`[error] gửi tới ${uid} thất bại:`, err.code || err.message);
    }
  }
}

function listen(name, handler) {
  db.collection(name)
    .where('created_at', '>', startedAt)
    .onSnapshot(
      (snap) => {
        snap.docChanges().forEach((change) => {
          if (change.type === 'removed') return;
          const data = change.doc.data();
          const stamp = data.created_at && data.created_at.toMillis();
          if (!firstTime(`${name}/${change.doc.id}/${stamp}`)) return;
          handler(change.doc.id, data).catch((e) =>
            console.error(`[${name}] lỗi xử lý ${change.doc.id}:`, e),
          );
        });
      },
      (err) => console.error(`[${name}] listener lỗi:`, err.message),
    );
  console.log(`Đang lắng nghe "${name}"...`);
}

// 1) Có người thích / super like
listen('swipes', async (_id, swipe) => {
  if (swipe.action !== 'like' && swipe.action !== 'super_like') return;

  // Nếu hai bên đã thích nhau thì thông báo "match" sẽ thay thế, không báo "có người thích".
  const reverse = await db
    .collection('swipes')
    .doc(`${swipe.swiped_id}_${swipe.swiper_id}`)
    .get();
  const reverseAction = reverse.exists ? reverse.data().action : null;
  if (reverseAction === 'like' || reverseAction === 'super_like') return;

  await pushToUser(swipe.swiped_id, likeNotification(swipe.action));
});

// 2) Match mới: user1 là người quẹt sau (đã thấy match trong app), user2 là người thích trước.
listen('matches', async (matchId, match) => {
  const actor = await getUser(match.user1_id);
  await pushToUser(
    match.user2_id,
    matchNotification(matchId, actor && actor.full_name),
  );
});

// 3) Tin nhắn mới
listen('messages', async (_id, msg) => {
  const matchSnap = await db.collection('matches').doc(msg.match_id).get();
  if (!matchSnap.exists) return;
  const users = matchSnap.data().users || [];
  const recipient = users.find((u) => u !== msg.sender_id);
  if (!recipient) return;

  const sender = await getUser(msg.sender_id);
  await pushToUser(
    recipient,
    messageNotification(
      msg.match_id,
      sender && sender.full_name,
      msg.message_type,
      msg.content,
    ),
  );
});

console.log('Push server đã chạy. Nhấn Ctrl+C để dừng.');
