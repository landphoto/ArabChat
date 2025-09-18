# ArabChat (Flutter + Node Backend)

Glassy Arabic chat MVP + username availability API and Socket.IO backend.

## Folders
- `lib/` Flutter app
- `backend/` Node.js (Express + Socket.IO + Prisma + SQLite)
- `.github/workflows/` CI for Flutter build (APK + Web + Pages) and backend

## Flutter (local)
```bash
flutter pub get
flutter run -d chrome    # or Android device
# Build artifacts
flutter build apk --release
flutter build web --release
```

## Backend (local)
```bash
cd backend
npm i
npx prisma migrate dev --name init
npm run seed
npm run dev  # http://localhost:4000
```
Endpoints:
- `GET /api/health`
- `GET /api/check-username?u=<name>` → `{ available: boolean, message: string }`
Socket.IO namespace: `/chat`

## Docker (backend)
```bash
docker compose up --build
```

## CI
- **flutter-ci.yml**: builds APK & Web, uploads artifacts, publishes GitHub Pages (Web), makes Release with APK
- **backend-ci.yml**: installs Node, runs Prisma, builds & uploads backend artifact

## Configure Flutter with API base
In `lib/config.dart` set `apiBaseUrl` to your backend URL (default `http://localhost:4000`).

## Termux – رفع المشروع إلى GitHub
See bottom section of this README for full commands.


# Termux: رفع المشروع على GitHub

> ملاحظات سريعة: تحتاج حساب GitHub ومفتاح SSH.

## 1) تثبيت الأدوات
```bash
pkg update && pkg upgrade -y
pkg install -y git openssh unzip
```

## 2) إضافة مفتاح SSH (أول مرة فقط)
```bash
ssh-keygen -t ed25519 -C "your_email@example.com"
# اضغط Enter لكل سؤال
cat ~/.ssh/id_ed25519.pub
# انسخ المفتاح وأضفه في GitHub -> Settings -> SSH and GPG keys -> New SSH key
```

## 3) تنزيل الأرشيف ونقله
```bash
# انسخ arabchat_fullstack.zip إلى ذاكرة الهاتف أو نزّله مباشرةً
# إذا عندك الرابط/الملف في Downloads مثلاً:
cd ~
mkdir -p projects && cd projects
# انقل zip إلى هذا المجلد ثم:
unzip arabchat_fullstack.zip
cd arabchat_fullstack/arabchat
```

## 4) تهيئة git والرفع
```bash
git init
git config user.name "Your Name"
git config user.email "your_email@example.com"
git add .
git commit -m "Initial ArabChat fullstack"
git branch -M main

# اربط الريبو عبر SSH (يوصى به في Termux)
git remote add origin git@github.com:USERNAME/REPO.git
git push -u origin main
```

## 5) إعداد Secrets (اختياري)
في GitHub -> Settings -> Secrets and variables -> Actions
- أضف `API_BASE_URL` إذا تريد الـ Web يستعمل عنوان سيرفرك الحقيقي.

## 6) نتائج الـ CI
- APK: عبر **Actions artifacts** و **Releases**.
- Web: مفعّل على **GitHub Pages** من الـ CI تلقائياً.
