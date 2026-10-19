# Central de notificaciones

Monolito Rails 8.1 que centraliza las notificaciones de la plataforma:

- **Definir** una notificación una sola vez, con contenido semántico (título, cuerpo y acción), sin mencionar canales.
- **Enviarla** con una llamada desde cualquier módulo: `BirthdayNotification.deliver(to: employee, params: { ... })`.
- **Despachar** de forma asíncrona por email (SendGrid), con una política central de canales, filtro anti-spam, digest diario e historial para el cliente.

`deliver` solo escribe en PostgreSQL, dentro de la transacción del llamador (outbox transaccional con Solid Queue en la misma base). Nunca llama al proveedor.

## Requisitos

| Componente | Versión |
|---|---|
| Ruby | 3.4 |
| PostgreSQL | 18 (se usa `uuidv7()`) |
| Cliente `psql` / `pg_dump` | 18 (para `db/structure.sql`) |

No se usa Redis: la cola es Solid Queue en la base principal.

## Levantar la app

1. Base de datos en Docker (puerto 5436):

   ```bash
   docker run -d --name notification-hub-db -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres \
     -p 5436:5432 -v notification-hub-pgdata:/var/lib/postgresql postgres:18
   ```

   La conexión se configura con `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_USERNAME` y `DATABASE_PASSWORD` (por defecto `localhost:5436`, `postgres/postgres`). `DATABASE_URL` también funciona.

2. Deja el cliente de PostgreSQL 18 (`psql` / `pg_dump`) en el PATH:

   ```bash
   brew install postgresql@18            # macOS
   sudo apt install postgresql-client-18 # Debian/Ubuntu (repositorio PGDG)
   ```

   En Windows con RubyInstaller: `ridk exec pacman -S --needed mingw-w64-ucrt-x86_64-postgresql` y luego `ridk enable`.

3. Dependencias, base y datos de ejemplo (2 empresas, 50 colaboradores, un administrador y un miembro por empresa, y unas 30 notificaciones ya despachadas para ver el historial):

   ```bash
   bundle install
   bin/rails db:prepare db:seed
   ```

   Las llaves de cifrado (Active Record Encryption) viven en `config/credentials.yml.enc`; pide `config/master.key` al equipo o define `RAILS_MASTER_KEY`.

4. Servidor web y worker de Solid Queue:

   ```bash
   bin/rails server
   bin/jobs          # en otra terminal: despacho, digest y tareas recurrentes
   ```

5. Abre http://localhost:3000 (historial de notificaciones) y elige un usuario administrador en el selector de la parte superior. La autenticación real queda fuera de alcance.

| URL | Para qué |
|---|---|
| `/` o `/historial-notificaciones` | Historial para el administrador de cada empresa |
| `POST /webhooks/sendgrid` | Event Webhook firmado de SendGrid |
| `/unsubscribe/:token` (alias `/desuscribir/:token`) | Desuscripción de engagement en un clic |
| `/api-docs` | Swagger UI con el contrato de los endpoints ([docs/openapi.yaml](docs/openapi.yaml)); solo en local |

El kill switch de canales se maneja en la tabla `notification_channel_settings` (global con `company_id` nulo, o por empresa):

```ruby
NotificationChannelSetting.create!(company_id: nil, channel: "email", enabled: false)   # apaga email para todos
```

## Correr los tests

```bash
bin/rails db:test:prepare
bin/rails test
bin/rubocop
```

Los tests bloquean toda llamada HTTP (WebMock) y usan `Email::TestAdapter`.

## Enviar una notificación de prueba

En development los correos quedan en memoria (`NOTIFICATIONS_EMAIL_ADAPTER=test`, valor por defecto):

```ruby
# bin/rails console
employee = Employee.first
handle = BirthdayNotification.deliver(to: employee, params: { company: employee.company })
handle.status   # => :accepted (o :duplicate si ya se envió hoy)

Notifications::Dispatcher.call(handle.id)   # o deja que bin/jobs lo despache
NotificationRequest.find(handle.id).status  # => "completed"
Notifications::Channels::Email::TestAdapter.deliveries.last[:subject]
```

Para enviar por SendGrid en modo sandbox (no llega ningún correo real):

```bash
NOTIFICATIONS_EMAIL_ADAPTER=sendgrid SENDGRID_SANDBOX=true SENDGRID_FROM_EMAIL=tu@dominio.com bin/rails console
```

Guarda la API key en credentials (`sendgrid.api_key`) con `bin/rails credentials:edit`.

## Definir una notificación nueva

```bash
bin/rails g notification SurveyClosed --category=engagement --owner=people_team
```

El generador crea `app/notifications/survey_closed_notification.rb`, las claves en `config/locales/notifications.es.yml` y un test. Solo se declara `category` (`critical`, `operational` o `engagement`): la política central decide por qué canal sale.

Las notificaciones se envían desde el código de dominio de cada equipo (servicios o jobs), nunca desde controladores. El cop `Notifications/NoDeliverInControllers` lo verifica.

## Agregar un canal nuevo (p. ej. SMS)

Ningún archivo de `app/notifications` cambia:

1. **Renderer**: `lib/notifications/channels/sms/renderer.rb`, subclase de `Notifications::Channels::BaseRenderer`. Implementa `render(content:, overrides:, recipient:, locale:)` y devuelve un mensaje que responde a `text`.
2. **Adaptador**: `lib/notifications/channels/sms/twilio_adapter.rb`, subclase de `Notifications::Channels::BaseAdapter`. Implementa `deliver(message:, delivery:)` (devuelve el id del proveedor o lanza `TransientDeliveryError` / `PermanentDeliveryError`) y `contact_for(recipient)` (p. ej. `recipient.phone`).
3. **Registro** en `config/initializers/notifications.rb`:

   ```ruby
   Notifications::Channels::Registry.register(:sms, renderer: Notifications::Channels::Sms::Renderer,
                                                    adapter: Notifications::Channels::Sms::TwilioAdapter)
   ```

4. **Una línea en la política** (`config/notifications/channel_policy.rb`):

   ```ruby
   category :critical do
     strategy :fallback
     channels :email, :sms   # si email falla de forma definitiva, sale por SMS
   end
   ```

El test `test/notifications/channel_policy_test.rb` muestra este flujo con un canal falso.

## Prueba de carga

```bash
RAILS_MAX_THREADS=10 CLEANUP=1 bin/rails runner script/load_test.rb
```

Registra 50.000 requests con `deliver_many` en lotes de 1.000 y despacha 5.000 con `TestAdapter`. Reporta requests/s y despachos/s. `CLEANUP=1` vacía las tablas de la central al terminar.

## Variables de entorno

| Variable | Uso |
|---|---|
| `DATABASE_URL` o `DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_USERNAME` / `DATABASE_PASSWORD` | PostgreSQL 18 |
| `SENDGRID_API_KEY` | Respaldo local de la API key (preferir credentials `sendgrid.api_key`) |
| `SENDGRID_FROM_EMAIL` | Remitente |
| `SENDGRID_SANDBOX` | `true` para no enviar correos reales (por defecto `true`) |
| `SENDGRID_WEBHOOK_PUBLIC_KEY` | Verificación de firma del Event Webhook |
| `NOTIFICATIONS_EMAIL_ADAPTER` | `sendgrid` o `test` |
| `NOTIFICATIONS_SHADOW_MODE` | `true` por defecto: el anti-spam registra decisiones sin bloquear |
| `APP_HOST` | Host para las URLs de los correos |
| `JOB_CONCURRENCY`, `JOB_THREADS` | Procesos y threads del worker de Solid Queue |
