# AutoPilot

AutoPilot is a self-hosted, server-side automation platform. It stores tasks persistently, registers their triggers on startup, evaluates event conditions, and executes action chains on an always-on server.

## Run locally

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

Default local credentials:

- Email: `admin@autopilot.local`
- Password: `autopilot`

Set `JWT_SECRET` and `AUTOPILOT_ADMIN_PASSWORD` before exposing the service.

## Useful scripts

```bash
npm run build
npm run smoke
npm start
```

## Configuration

Copy `.env.example` to `.env` and fill in the integrations you need:

- `TELEGRAM_BOT_TOKEN`
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`
- `DISCORD_WEBHOOK_URL`
- `ANTHROPIC_API_KEY`
- `REDIS_URL`

SQLite is used by default through `DATABASE_URL=./data/autopilot.sqlite`. The schema lives in `migrations/001_initial.sql`.

## Task shape

Tasks have one trigger and one or more actions. The dashboard accepts JSON for both fields so every supported module is available without extra UI ceremony.

Example recurring trigger:

```json
{
  "type": "time_recurring",
  "cron_expression": "0 8 * * *",
  "human_label": "Every day at 8:00 AM"
}
```

Example event trigger:

```json
{
  "type": "event_poll",
  "poll_interval_seconds": 300,
  "condition": {
    "type": "http_contains",
    "params": {
      "url": "https://example.com/jobs",
      "keyword": "cybersecurity intern"
    }
  }
}
```
