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

# 5. Run server
uvicorn main:app --reload

# Server will be available at http://localhost:8000
# API docs: http://localhost:8000/docs
```

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

### Backend (.env)

```env
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_service_role_key
GOOGLE_GENAI_API_KEY=your_google_api_key
ENVIRONMENT=development
```

### Frontend (.env)

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
API_BASE_URL=http://localhost:8000
```

**Never commit .env files to version control**

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

## Security

* Environment variables for all secrets
* Supabase authentication layer
* CORS configuration
* Secure credential storage (Flutter)
* JWT token management
* Input validation (Pydantic)

**Security Checklist:**

* [ ] Never commit .env files
* [ ] Rotate API keys regularly
* [ ] Use HTTPS in production
* [ ] Enable Supabase RLS policies
* [ ] Validate all user inputs

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
