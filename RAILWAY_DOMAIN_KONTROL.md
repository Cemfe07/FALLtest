# Railway Domain ve Backend Kontrol Listesi

## Projede kullanılan domain

- **Backend (API):** `https://fall-production.up.railway.app`
- **Kullanıldığı yerler:**
  - `mobile/lib/services/api_base.dart` → `_railwayHost`
  - `FALL/mobile/lib/services/api_base.dart` → aynı
  - `codemagic.yaml` → `API_HOST`
  - `mobile/android/PLAY_STORE_IMZA.md` → build komutu

---

## Tespit etmen gerekenler (Railway + GitHub)

### 1. Railway’de servis ayakta mı?

- [ ] [Railway Dashboard](https://railway.app/) → proje → **fall-production** servisi **Active** mi?
- [ ] **Deployments** sekmesinde son deploy **Success** mı? (GitHub push sonrası otomatik deploy açıksa yeni commit deploy edilmiş olmalı.)

### 2. Domain erişilebilir mi?

- [ ] Tarayıcıda aç: `https://fall-production.up.railway.app/api/v1/health` (veya projede varsa bir health/status endpoint’i).
- [ ] 404/502/503 alıyorsan: servis kapalı, crash ediyor veya route yanlış demektir.

### 3. CORS (mobil uygulama → API)

- Backend `app/core/config.py` içinde **CORS_ORIGINS** env ile ayarlanıyor (varsayılan `*`).
- [ ] Railway’de bu servise ait **Variables** kısmında `CORS_ORIGINS` tanımlı mı? Gerek yoksa `*` bırakılabilir; özel domain kullanıyorsan ilgili origin’leri ekle.

### 4. Ortam değişkenleri (Railway Variables)

- [ ] `OPENAI_API_KEY` → yorum üretimi için gerekli.
- [ ] `DATABASE_URL` → Railway’de genelde otomatik (Postgres vs.); SQLite kullanıyorsan dosya yolu/volume doğru mu?
- [ ] İsteğe bağlı: `CORS_ORIGINS`, `GOOGLE_PLAY_PACKAGE_NAME`, `APPLE_BUNDLE_ID` (ödeme doğrulama için).

### 5. GitHub – Railway bağlantısı

- [ ] Railway projesi bu repo’ya (**ANLGZL52/FALL**) bağlı mı? (Connect Repo)
- [ ] **main** branch deploy ediliyor mu? Push sonrası yeni deploy tetiklenmiş mi kontrol et.

### 6. Mobil uygulama – API host

- Uygulama `ApiBase.host` ile `https://fall-production.up.railway.app` kullanıyor (veya build’de `--dart-define=API_HOST=...` ile override).
- [ ] Gerçek cihazda/emülatörde bir ekran açıp (örn. giriş, profil, okuma listesi) istek atıyor musun? Log/network’te bu domain’e giden istekler 200/201 dönüyor mu?

---

## Hızlı test komutları

```bash
# API erişim (curl ile)
curl -s -o /dev/null -w "%{http_code}" https://fall-production.up.railway.app/api/v1/

# Health/root varsa
curl -s https://fall-production.up.railway.app/
```

- **200** veya **404** (path yoksa) genelde servisin ayakta olduğunu gösterir.
- **502 Bad Gateway** / **503** → servis kapalı veya crash.
- **SSL/certificate** hatası → Railway domain sertifikası otomatik; büyük ihtimalle geçicidir veya farklı bir domain kullanıyorsundur.

---

Bu listeyi adım adım doldurarak Railway domain ve backend’in düzgün çalışıp çalışmadığını tespit edebilirsin.
