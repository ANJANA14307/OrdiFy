# OrdiFy - Smart Order Management Platform

**OrdiFy** is a production-ready order management and fulfillment platform designed for e-commerce sellers. It integrates Instagram commerce, AI-powered suggestions, automated invoicing, and multi-channel payment processing.

---

## Features

* **Mobile-First Flutter App** - Beautiful, responsive UI for iOS and Android
* **REST API Backend** - FastAPI-powered microservices architecture
* **Order Management** - Create, track, and fulfill orders seamlessly
* **Multi-Channel Payments** - Support for COD, Razorpay, and more
* **Instagram Integration** - Sync orders directly from Instagram
* **AI Suggestions** - Smart recommendations powered by Google Generative AI
* **Invoice Generation** - Automatic PDF invoicing with branding
* **Analytics Dashboard** - Real-time sales metrics and insights
* **Notifications** - Real-time order and payment updates
* **Enterprise Security** - Supabase authentication, secure credential management

---

## Architecture

### Frontend

* **Framework:** Flutter + Dart
* **State Management:** Flutter Riverpod
* **Routing:** GoRouter
* **UI Libraries:** Material 3, Google Fonts
* **Backend Communication:** Dio HTTP client
* **Database:** Supabase

### Backend

* **Framework:** FastAPI
* **Database:** PostgreSQL (via Supabase)
* **APIs:**

  * Authentication & Profile
  * Order Management
  * Payment Processing
  * Invoice Generation
  * Customer Management
  * Product Catalog
  * Analytics & Reporting
  * AI Chat & Suggestions
  * Activity Logs
  * Notifications
  * Instagram Integration
  * Instagram Redirect Tools
  * WhatsApp Ordering
  * Returns Management
  * Shared Product Catalog and Business Listings

---

## Quick Start

### Prerequisites

* Flutter SDK (^3.12.1)
* Python 3.9+
* Supabase account
* Google API key (for AI features)

### Backend Setup

```bash
# 1. Clone repository
git clone https://github.com/ANJANA14307/OrdiFy.git
cd OrdiFy/backend

# 2. Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure environment
cp .env.example .env
# Edit .env with your Supabase and API keys

# 5. Ensure the existing core tables (profiles, products, orders, customers,
#    and order_items) are present, then run these SQL files in the Supabase SQL Editor:
#    catalog_settings.sql, product_variants.sql, delivery_fees.sql,
#    returns.sql, instagram_redirect.sql, whatsapp_orders.sql,
#    shared_catalog.sql (in that order)
# 6. Set PUBLIC_CATALOG_BASE_URL to the deployed Flutter web app origin
# 7. Configure WHATSAPP_ACCESS_TOKEN, WHATSAPP_VERIFY_TOKEN, and META_APP_SECRET
#    to enable the WhatsApp Cloud API webhook and outgoing messages
# 8. Register https://<your-api-host>/webhooks/whatsapp as the Meta webhook URL
#    and subscribe it to WhatsApp messages
# 9. Set PUBLIC_API_BASE_URL to this backend's public HTTPS origin for tracked
#    Instagram redirect links
# 10. Register https://<your-api-host>/webhooks/instagram as an Instagram
#     messaging webhook using VERIFY_TOKEN and META_APP_SECRET

# 11. Run server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Server will be available at http://localhost:8000
# API docs: http://localhost:8000/docs
```

### WhatsApp Ordering

The business saves its international WhatsApp number and Meta Cloud API phone
number ID under Settings → WhatsApp Ordering. The Cloud API access token,
webhook verification token, and Meta app secret remain on the backend; they are
never entered into or returned to the mobile app. The backend webhook parses
`ORDER <CODE> / QTY 1 / NAME ... / PHONE ... / PIN ... / ADDRESS ... / PAYMENT COD`,
checks the active business variant, current variant stock, and backend delivery
quote, then asks the customer to reply `CONFIRM <reference>`. An OrdiFy order is
created only after that confirmation (or the business explicitly confirms it
after verifying customer consent).

Apply `database/whatsapp_orders.sql` after the profile, order, and product
variant tables exist. In Meta Developer settings, set the callback URL to
`https://<your-api-host>/webhooks/whatsapp`, use the configured verify token,
and subscribe the WhatsApp account to message events. The confirmation message
is sent as a text reply; shipped/delivered text messages use the saved message
templates when an associated order changes status. Meta may reject free-form
messages outside its customer-service window; failures are recorded in the
order timeline and returned to the order status UI.

### Instagram Redirect Tools

Settings → Instagram Tools generates tracked bio/catalog, WhatsApp, and
product-caption links from the backend. Apply `database/instagram_redirect.sql`
after the catalog and product-variant migrations, publish the catalog, and set
`PUBLIC_API_BASE_URL` to the public backend HTTPS origin. The migration also
adds the Instagram account fields to `profiles`. Instagram DM auto
replies are opt-in: configure `INSTAGRAM_ACCESS_TOKEN`, `META_APP_SECRET`, and
`VERIFY_TOKEN`, register `/webhooks/instagram` in Meta, subscribe it to
Instagram messaging events, connect the business account, and configure the
catalog and WhatsApp number. Auto replies contain tracked catalog and WhatsApp
links only; they do not create orders on Instagram. Instagram DM orders are
created through the existing OrdiFy order-management flow.

### Returns

Settings → Return Policy configures the return window, eligible conditions,
non-returnable products, refund/exchange options, and customer-facing policy.
For delivered orders, order detail checks backend eligibility before showing
the request-return action. Businesses manage requests in Orders → Returns.
Inventory is restored only by the transactional inspection RPC and only for
accepted quantities; cancellation remains a separate, unchanged workflow.

The return-request form is part of the authenticated app because OrdiFy does
not currently provide a public customer order portal. Apply
`database/returns.sql` after the order, customer, product, and product-variant
tables exist. Refunds are recorded against a return request; processing money
through a payment provider remains an external business operation.

### Local Network Testing

Open http://127.0.0.1:8000/health on the computer running the backend.
Flutter web on that computer uses http://localhost:8000 by default; Android
emulators use http://10.0.2.2:8000. For a physical phone, set API_BASE_URL to
the computer's Wi-Fi IPv4 address (for example,
`flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8000`) and keep the
phone and computer on the same Wi-Fi network. Local development CORS allows
localhost and private-LAN origins on any port; this exception is disabled
outside local/development environments.

The backend also needs `PUBLIC_CATALOG_BASE_URL` to generate catalog preview
and sharing links. Links use GoRouter's hash URL format
(`https://app.example/#/catalog/<slug>`), so static hosting does not need a
single-page-app path rewrite. For local Flutter web, set it to the app's origin
(for example, `http://localhost:59358`) and launch Flutter with the same fixed
port using `flutter run -d chrome --web-port 59358`. For production, use the
deployed Flutter web origin.

Instagram tracked redirects also require `PUBLIC_API_BASE_URL`; use
`http://127.0.0.1:8000` for local backend testing and the public HTTPS backend
origin in production. Restart the backend after changing `.env`.

### Shared Catalog Listings

Inventory → Add Product offers “Find in OrdiFy catalog” or “Add new product.”
Approved catalog product details are shared and read-only; each business listing
stores its own price, stock, variant codes, delivery override, and return-policy
override. Search/detail APIs return common catalog metadata only, while listing
APIs are scoped to the signed-in business. Catalog product suggestions are saved
as `pending_review` and are not sellable until approved through the catalog
review process. Review endpoints require the Supabase user's server-managed
`app_metadata.catalog_admin: true` or `app_metadata.role: "admin"`; no reviewer
screen is included. Existing products can be linked using the separate
`product_catalog_mappings` table without changing the product model.

Apply `database/shared_catalog.sql` after `database/catalog_settings.sql`,
`database/product_variants.sql`, and the product tables. Selected active
business listings can also be added to the business's public shared catalog.

### Frontend Setup

```bash
# 1. Navigate to app directory
cd OrdiFy/ordify_app

# 2. Install dependencies
flutter pub get

# 3. Configure environment
cp .env.example .env
# Edit .env with your Supabase credentials

# 4. Run app
flutter run

# For Android:
flutter run -d android

# For iOS:
flutter run -d ios
```

---

## Project Structure

```text
OrdiFy/
├── ordify_app/                 # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart          # App entry point
│   │   ├── core/              # Configuration, routing, error handling
│   │   └── presentation/      # UI screens and widgets
│   ├── pubspec.yaml           # Dependencies
│   └── .env.example           # Environment template
│
├── backend/                    # FastAPI server
│   ├── main.py                # Application entry point
│   ├── routers/               # API endpoints (13 routers)
│   │   ├── auth.py            # Authentication
│   │   ├── orders.py          # Order management
│   │   ├── payments.py        # Payment processing
│   │   ├── invoices.py        # Invoice generation
│   │   ├── customers.py       # Customer management
│   │   ├── products.py        # Product catalog
│   │   ├── analytics.py       # Analytics
│   │   ├── ai_chat.py         # AI chat interface
│   │   ├── ai_suggestions.py  # AI recommendations
│   │   └── ...more            
│   ├── core/                  # Configuration and settings
│   ├── schemas/               # Pydantic models
│   ├── services/              # Business logic
│   ├── requirements.txt       # Python dependencies
│   └── .env.example           # Environment template
│
├── README.md                  # This file
└── .gitignore
```

---

## Environment Variables

### Backend (`backend/.env`)

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SECRET_KEY=your_service_role_key
PUBLIC_CATALOG_BASE_URL=https://your-deployed-app.example
BACKEND_CORS_ORIGINS=https://your-deployed-app.example
ENVIRONMENT=development
```

### Flutter build-time configuration

Flutter does not load a `.env` file in this project. Supply the API origin at
build time; release builds require a public HTTPS URL and reject localhost:

```powershell
cd ordify_app
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example
```

The Supabase anon key is a public client key; keep the service-role key and all
payment, webhook, and Cloudinary secrets backend-only. Never commit `.env` files.

---

## API Endpoints

### Health Check

```bash
GET /health
GET /
```

### Authentication

```bash
POST /auth/register
POST /auth/login
POST /auth/logout
```

### Orders

```bash
GET    /orders/
POST   /orders/
GET    /orders/{order_id}
PATCH  /orders/{order_id}
DELETE /orders/{order_id}
```

### Payments

```bash
POST   /payments/create-payment
POST   /payments/webhook/razorpay
GET    /payments/{order_id}/status
```

### Product Variants

```bash
GET    /products/{product_id}/variants
POST   /products/{product_id}/variants
PATCH  /products/{product_id}/variants/{variant_id}
```

### Delivery Fees

```bash
GET    /delivery-fees/settings
PUT    /delivery-fees/settings
POST   /delivery-fees/quote
```

### Catalogs

```bash
GET    /catalogs/me
PUT    /catalogs/me
GET    /catalogs/public/{slug}
```

Apply the SQL files in `database/` to Supabase before using database-backed features. Set `PUBLIC_CATALOG_BASE_URL` to the actual deployed Flutter web app origin; the backend generates hash-routed customer-facing links from this value.
### Invoices

```bash
POST   /invoices/generate
GET    /invoices/{invoice_id}
POST   /invoices/{invoice_id}/email
```

### AI Features

```bash
POST   /ai-chat/send-message
POST   /ai-suggestions/get-suggestions
```

See full API documentation at `http://localhost:8000/docs`

---

## Production deployment checklist

1. Deploy the FastAPI backend with `ENVIRONMENT=production`,
   `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, the public
   `PUBLIC_CATALOG_BASE_URL`, and exact HTTPS `BACKEND_CORS_ORIGINS`.
2. Set optional integration secrets only when those features are enabled.
   Razorpay requires its keys, webhook secret, and HTTPS callback URL in
   production. Cloudinary uploads remain in durable Cloudinary storage and are
   limited to 10 MB per image; enforce a request-body limit at the gateway too.
3. Build the Flutter web app with
   `flutter build web --release --dart-define=API_BASE_URL=https://<api-host>`.
   Publish `ordify_app/build/web` at the origin configured above.
4. Configure rate limits at the API gateway/hosting edge for authentication,
   payment, upload, and webhook routes. The application does not implement a
   distributed rate limiter.
5. Apply schema migrations and verify Supabase RLS/backups before enabling
   production traffic.

Before cutover, check `GET /health`, sign in, load a public catalog link, search
catalog products, upload an image, and exercise an order/payment in sandbox
mode. Keep the prior frontend/backend release available for rollback; revert
both together if an API contract changes.

---

## Troubleshooting

### Backend Won't Start

```bash
# Clear cache and reinstall
pip install --force-reinstall -r requirements.txt
python -c "import main; print('OK')"
```

### Flutter Dependencies Issue

```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### Supabase Connection Error

* Verify .env has correct SUPABASE_URL and SUPABASE_ANON_KEY
* Check Supabase project is active
* Ensure your IP is not blocked

---

## Documentation

* [Flutter Docs](https://flutter.dev/docs)
* [FastAPI Docs](https://fastapi.tiangolo.com/)
* [Supabase Docs](https://supabase.com/docs)
* [Google AI Docs](https://ai.google.dev/)

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see LICENSE file for details.

---

## Author

**Anjana** - [GitHub Profile](https://github.com/ANJANA14307)

---

## Deployment

### Local Development

```bash
# Terminal 1: Backend
cd backend && uvicorn main:app --reload

# Terminal 2: Frontend
cd ordify_app && flutter run
```

### Production

See [DEPLOYMENT.md](./DEPLOYMENT.md) for cloud deployment guides (AWS, Heroku, Firebase).

---

**Made with love for e-commerce sellers**
