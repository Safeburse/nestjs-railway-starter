# Oriva Asset API

NestJS 11 + Prisma 7 for Wealth Asset Management. Schema is 1:1 with
`doc/sql/oriva_asset_mvp.sql` (Deliverable B). Domain modules match README §42
and do not expose HTTP until their stories land. The only public routes are
`GET /` and `GET /health`.

## What's in here

| File | Why it exists |
|------|---------------|
| `src/main.ts` | Bootstrap: validation pipe, shutdown hooks, binds `PORT` |
| `src/prisma/` | Prisma client as a global injectable |
| `src/health/` | `/` and `/health` — the latter runs `SELECT 1` |
| `src/{auth,organizations,...}/` | Empty §42 modules (no controllers) |
| `prisma/migrations/20260904120000_oriva_asset_mvp/` | Full B DDL; drops the template `Note` table |
| `railway.json` | Pre-deploy migration, health check, restart policy |

- **Migrations run in `preDeployCommand`**, after the build and before the new
  version takes traffic. `predeploy.sh` retries only Prisma `P1001`.
- **`whitelist: true` on the validation pipe** strips undeclared DTO fields.
- **`enableShutdownHooks()`.** Railway sends `SIGTERM` before replacing a
  container.
- **Deployment-agnostic.** Domain modules do not import cloud SDKs. Hosting
  is `DATABASE_URL` plus S3-compatible env vars.

## Endpoints

| Method | Path | Does |
|--------|------|------|
| GET | `/` | Service name and health path |
| GET | `/health` | Runs `SELECT 1`; reports degraded when Postgres is unreachable |

## Run locally

```bash
npm ci
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/oriva_asset"
npx prisma migrate deploy
npm run dev
```

Do not commit `.env` files. Set variables in the shell locally and in the host's dashboard (Railway) for deploys.

## Configuration

| Variable | Required | Purpose |
|----------|----------|---------|
| `DATABASE_URL` | yes | Postgres connection string |
| `PORT` | no | Defaults to 8080 |
| `S3_ENDPOINT` | later | S3-compatible API URL |
| `S3_REGION` | later | Bucket region |
| `S3_BUCKET` | later | Object-store bucket |
| `S3_ACCESS_KEY` | later | Object-store access key |
| `S3_SECRET_KEY` | later | Object-store secret key |
