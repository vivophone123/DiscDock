# DiscDock

แอปร้านขายแผ่นเกมขนาดเล็ก (PS5 / PS4 / Nintendo Switch ทั้งมือหนึ่งและมือสอง) สำหรับวิชา Advanced Computer Programming ประเภท Micro-commerce พัฒนาด้วย Flutter และ Firebase ทำงานบนอุปกรณ์ Android จริง

- **ไฟล์ติดตั้ง (APK):** -https://github.com/vivophone123/DiscDock/releases/tag/v1.0

## ปัญหาที่แอปแก้

| ปัญหาของร้าน | ฟีเจอร์ที่แก้ |
|---|---|
| ลูกค้าถามซ้ำว่ามีเกมไหน เครื่องอะไร มือหนึ่ง/สอง | ค้นหา กรองแพลตฟอร์ม/สภาพ ตัวเลือกโซนและกล่อง |
| สต๊อกไม่ตรง ขายซ้ำ (มือสองมีชิ้นเดียว) | ตัดสต๊อกอัตโนมัติแบบ transaction |
| โอนเงินแล้วต้องส่งสลิป | PromptPay QR ตามยอดจริง เจ้าของร้านยืนยันในแอป |
| ไม่แน่ใจสภาพแผ่นมือสอง | อัปโหลดรูปจริงได้ถึง 5 รูป |
| เจ้าของร้านไม่เห็นภาพรวม | Dashboard ยอดขาย เกมขายดี แผ่นใกล้หมด |

## ฟีเจอร์ตามโจทย์

| โจทย์ | สถานะ |
|---|---|
| ระบบสมาชิก (สมัคร/ล็อกอิน/แก้ไข/ลบบัญชี) | ✅ |
| เลือกสินค้า + ตะกร้า + ชำระเงิน + ยืนยันการชำระ | ✅ (PromptPay QR + เจ้าของร้านกดยืนยันรับเงิน) |
| เจ้าของร้านเพิ่ม/ลบ/แก้ไขสินค้า ตัวเลือกย่อย | ✅ (แพลตฟอร์ม สภาพ โซน กล่อง) |
| Dashboard เจ้าของร้าน | ✅ |
| รายการสินค้า ค้นหา/กรอง | ✅ |
| แชทลูกค้า-ร้าน (ข้อความ/รูป) | ✅ |
| คูปองส่วนลด | ✅ (ลด % / ลดเป็นบาท ขั้นต่ำ จำกัดจำนวนครั้ง) |
| ประวัติคำสั่งซื้อ | ✅ |
| สต๊อกสินค้า | ✅ |
| อัปโหลดรูปสินค้าหลายรูป | ✅ (Cloudinary) |
| ฐานข้อมูลบน Cloud | ✅ (Cloud Firestore) |
| ฟีเจอร์ตาม pain point | ✅ แจ้งเตือนในแอป, รูปจริงของแผ่นมือสอง, ป้ายสต๊อก |

## เทคโนโลยี

- Flutter (Dart)
- Firebase Authentication (Email/Password)
- Cloud Firestore (+ Security Rules)
- Cloudinary (เก็บรูปภาพ แบบ unsigned preset)
- qr_flutter (สร้าง PromptPay QR), image_picker, http

## โครงสร้างโปรเจ็กต์

```
lib/
├── main.dart
├── app/                theme.dart
├── core/               constants/ utils/ (promptpay.dart)
├── services/           cloudinary_service.dart
└── features/
    ├── auth/           สมัคร ล็อกอิน โปรไฟล์ ลบบัญชี
    ├── products/       รายการ ค้นหา/กรอง รายละเอียด ฟอร์มสินค้า
    ├── cart/           ตะกร้า คูปอง
    ├── orders/         สั่งซื้อ (transaction) ชำระเงิน ประวัติ จัดการออเดอร์
    ├── chat/           แชทข้อความ/รูป
    ├── coupons/        จัดการคูปอง
    ├── dashboard/      Dashboard เจ้าของร้าน
    └── notifications/  แจ้งเตือนในแอป
```

## Database Schema (Cloud Firestore)

| คอลเลกชัน | ฟิลด์หลัก |
|---|---|
| `users/{uid}` | name, email, phone, role (customer/owner), createdAt, updatedAt |
| `products/{id}` | title, platform, condition, region, hasBox, price, stock, description, imageUrls[], createdAt |
| `orders/{id}` | userId, items[], subtotal, discount, couponCode, total, shipping{name,phone,address}, status, carrier, trackingNumber, createdAt |
| `coupons/{code}` | type (percent/fixed), value, minSpend, maxUses, usedCount, active |
| `chats/{customerUid}` | customerName, lastMessage, updatedAt และ `messages/{id}`: text, imageUrl, senderId, isOwner, createdAt |
| `notifications/{id}` | toUid หรือ toRole, title, body, read, createdAt |

กฎความปลอดภัยของฐานข้อมูลอยู่ในไฟล์ `docs/firestore.rules`

## บัญชีสำหรับทดสอบ

| บทบาท | อีเมล | รหัสผ่าน |
|---|---|---|
| เจ้าของร้าน | <อีเมล> | <รหัสผ่าน> |
| ลูกค้า | <อีเมล> | <รหัสผ่าน> |

บัญชีใหม่ที่สมัครเองจะเป็นลูกค้าเสมอ ส่วนเจ้าของร้านต้องตั้งฟิลด์ `role` เป็น `owner` ใน Firebase Console

## วิธีรันจากซอร์สโค้ด

1. ติดตั้ง Flutter SDK และเปิด USB debugging บนมือถือ Android
2. `flutter pub get`
3. เชื่อม Firebase ของตัวเองด้วย `flutterfire configure` (ไฟล์ `firebase_options.dart` ในโปรเจ็กต์นี้ผูกกับโปรเจ็กต์ของผู้พัฒนา)
4. ใส่ค่าใน `lib/core/constants/cloudinary_config.dart` (cloud name และ unsigned upload preset)
5. `flutter run`

## ข้อจำกัดที่ทราบ

- การแจ้งเตือนเป็นแบบในแอป (ไม่ใช่ push ตอนปิดแอป เพราะต้องใช้ Cloud Functions)
- คำนวณยอดและตัดสต๊อกที่ฝั่งแอป (ป้องกันด้วย transaction และ Security Rules) การป้องกันที่สมบูรณ์ต้องย้ายไปฝั่งเซิร์ฟเวอร์
- การชำระเงินใช้ PromptPay QR และเจ้าของร้านยืนยันเอง ไม่ได้เชื่อม payment gateway อัตโนมัติ
- รูปภาพอัปโหลดผ่าน Cloudinary แบบ unsigned preset