'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const m = require('./messages');

test('like ẩn danh và trỏ tới /likes', () => {
  const n = m.likeNotification('like');
  assert.equal(n.type, 'like');
  assert.equal(n.route, '/likes');
  assert.ok(!/undefined|null/.test(n.body));
  assert.match(m.likeNotification('super_like').title, /Super Like/);
});

test('match mở phòng chat và có tên người kia, fallback khi thiếu tên', () => {
  const n = m.matchNotification('a_b', 'Vân Anh');
  assert.equal(n.route, '/chat/a_b');
  assert.match(n.body, /Vân Anh/);
  assert.match(m.matchNotification('a_b', '  ').body, /Ai đó/);
});

test('tin nhắn: text cắt ngắn, ảnh có nhãn riêng, tên người gửi làm tiêu đề', () => {
  const long = 'x'.repeat(300);
  const t = m.messageNotification('a_b', 'Lan', 'text', long);
  assert.equal(t.title, 'Lan');
  assert.ok(t.body.length <= 120);
  assert.equal(m.messageNotification('a_b', 'Lan', 'image', 'u.jpg').body, 'Đã gửi một ảnh 📷');
  assert.equal(m.messageNotification('a_b', '', 'text', '').title, 'Tin nhắn mới');
});

test('toFcmMessage đặt đúng channel, data và priority', () => {
  const msg = m.toFcmMessage('tok', m.matchNotification('a_b', 'Lan'));
  assert.equal(msg.token, 'tok');
  assert.equal(msg.android.notification.channelId, m.CHANNEL_ID);
  assert.equal(msg.android.priority, 'high');
  assert.deepEqual(msg.data, { type: 'match', route: '/chat/a_b' });
});

test('nhận diện token chết', () => {
  assert.ok(m.isDeadTokenError({ code: 'messaging/registration-token-not-registered' }));
  assert.ok(!m.isDeadTokenError({ code: 'messaging/internal-error' }));
  assert.ok(!m.isDeadTokenError(null));
});
