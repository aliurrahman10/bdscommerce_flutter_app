# BDS Commerce Mobile Starter

Flutter starter for one Android app with two modes:

- Client Portal
- Store Admin

Backend endpoints already used:

- Portal: `https://portal.biswasdigitalsolution.com/api/mobile/portal`
- Store: `https://app.biswasdigitalsolution.com/api/mobile/store`

## Setup

```bash
flutter create --platforms=android .
flutter pub get
```

For push notification, add Firebase Android app and place:

```text
android/app/google-services.json
```

Then configure Android Gradle for Firebase using FlutterFire docs or FlutterFire CLI.

## Current MVP included

- Portal login
- Store login with tenant slug
- Separate token storage per mode
- Mode switching without logout
- Portal dashboard/services/notifications
- Store dashboard/orders/order statuses
- Device token save foundation

## Important

After Firebase is configured, app will send FCM token to server using:

- `/api/mobile/portal/device-token`
- `/api/mobile/store/device-token`
