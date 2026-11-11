# Firebase key: tính hạn từ lần kích hoạt đầu tiên

Project: huyminh-458e1. Anonymous Auth phải bật. Admin UID trong Rules là UID đã được chủ dự án cung cấp.

Key mới: durationSeconds là số giây, activatedAt và expiresAt ban đầu null. Lần nhập hợp lệ đầu tiên ghi activatedAt bằng server timestamp. Hạn được suy ra từ activatedAt + durationSeconds. Client đọc lại sau commit; dùng updateTime precondition để tránh ghi đè khi nhiều máy cùng nhập.

Không dùng Rules cũ chỉ cho sửa expiresAt: bản này cần quyền activatedAt có kiểm soát. Hãy triển khai client/admin mới cùng Rules dưới đây trước khi tạo key duration. Key cũ có expiresAt vẫn giữ hạn cũ.

Chưa build IPA trên Windows. Dùng workflow build-ipa.yml trong GitHub Actions hoặc Xcode/macOS.

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAdmin() {
      return request.auth != null && request.auth.uid == "aYliuZ3rwcONomJU3zi7A8nf1ek2";
    }
    function inWindow(data) {
      let expiry = data.get('expiresAt', null);
      let seconds = data.get('durationSeconds', null);
      let activated = data.get('activatedAt', null);
      return expiry != null
        ? expiry is timestamp && request.time < expiry
        : seconds == null || (seconds is int && seconds > 0 && seconds <= 315360000
          && (activated == null || (activated is timestamp && request.time < activated + duration.value(seconds, 's'))));
    }
    function activationIsValid() {
      let old = resource.data;
      let next = request.resource.data;
      let first = old.get('durationSeconds', null) != null && old.get('expiresAt', null) == null && old.get('activatedAt', null) == null;
      return (first ? next.get('activatedAt', null) == request.time : next.get('activatedAt', null) == old.get('activatedAt', null))
        && (old.get('boundAt', null) == null ? next.get('boundAt', null) == request.time : next.get('boundAt', null) == old.get('boundAt', null));
    }
    function bindingIsValid() {
      let old = resource.data;
      let next = request.resource.data;
      let before = old.get('devices', {});
      let after = next.get('devices', {});
      let id = next.get('deviceID', '');
      let legacy = old.get('deviceID', '');
      let known = before.keys().hasAny([id]) || (legacy != '' && legacy == id);
      let count = before.size() + (legacy != '' && !before.keys().hasAny([legacy]) ? 1 : 0);
      let used = old.get('usedUsers', 0) > count ? old.get('usedUsers', 0) : count;
      return before is map && after is map && id is string && id.matches('[A-Za-z0-9_-]{1,128}')
        && next.get('authUID', '') == request.auth.uid
        && after.diff(before).affectedKeys().hasOnly([id])
        && (before.keys().hasAny([id]) ? after[id] == before[id] : after[id] == request.auth.uid)
        && next.get('usedUsers', -1) == used + (known ? 0 : 1)
        && next.get('usedUsers', -1) <= old.get('maxUsers', 1)
        && after.size() <= old.get('maxUsers', 1)
        && after.keys().hasAny([id]);
    }
    match /keys/{keyId} {
      allow read, list, create, update, delete: if isAdmin();
      allow get: if request.auth != null && resource.data.get('allowed', false) == true && inWindow(resource.data);
      allow update: if request.auth != null && resource.data.get('allowed', false) == true && inWindow(resource.data)
        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['devices', 'usedUsers', 'deviceID', 'authUID', 'boundAt', 'activatedAt'])
        && activationIsValid() && bindingIsValid();
      allow create, delete, list: if false;
    }
  }
}

```
