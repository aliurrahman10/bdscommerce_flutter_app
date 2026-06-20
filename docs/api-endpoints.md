# BDS Commerce Mobile API Endpoints

## Portal

Base: `https://portal.biswasdigitalsolution.com/api/mobile/portal`

- `POST /login`
- `GET /me`
- `GET /dashboard`
- `GET /services`
- `GET /payments`
- `GET /notifications`
- `POST /device-token`
- `POST /logout`

## Store

Base: `https://app.biswasdigitalsolution.com/api/mobile/store`

- `POST /tenant/resolve`
- `POST /login`
- `GET /me`
- `GET /dashboard`
- `GET /orders`
- `GET /orders/{order}`
- `PATCH /orders/{order}/status`
- `GET /order-statuses`
- `POST /device-token`
- `POST /logout`

## Mode switching

The app stores separate secure tokens:

- portal token
- store token by tenant slug

Switching mode does not logout the user.
