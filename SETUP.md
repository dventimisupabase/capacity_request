# Setup Guide: Capacity Request Workflow

This guide walks through setting up the Slack app, deploying the proxy, and connecting everything to Supabase.

## Prerequisites

- A Supabase project (local or hosted) with all 6 migrations applied
- A Slack workspace where you have permission to install apps
- A Cloudflare account (if using the Worker proxy) or Supabase CLI (if using the Edge Function proxy)

---

## Step 1: Create the Slack App

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App**
3. Choose **From a manifest**
4. Select your workspace from the dropdown, then click **Next**
5. Choose **YAML** format
6. Paste the contents of `slack-app-manifest.yaml` from this repo
7. Click **Next**, review the summary, then click **Create**

You now have a Slack app. Don't close this page — you'll need it for the next steps.

---

## Step 2: Collect Your Credentials

### Bot Token

1. In the left sidebar, click **OAuth & Permissions**
2. Click **Install to Workspace** (or reinstall if already installed)
3. Authorize the app when prompted
4. Copy the **Bot User OAuth Token** — it starts with `xoxb-`

### Signing Secret

1. In the left sidebar, click **Basic Information**
2. Scroll to **App Credentials**
3. Click **Show** next to **Signing Secret** and copy it

---

## Step 3: Store Secrets in Supabase Vault

### Via the Supabase Dashboard (recommended)

1. Go to your Supabase project dashboard
2. Navigate to **Settings → Vault**
3. Click **Add new secret** and create these two secrets:

| Name                   | Value                                    |
|------------------------|------------------------------------------|
| `SLACK_BOT_TOKEN`      | The `xoxb-...` token from Step 2         |
| `SLACK_SIGNING_SECRET`  | The signing secret from Step 2           |

### Via SQL (local development only)

For local development with `supabase start`, you can insert secrets directly:

```sql
SELECT vault.create_secret('xoxb-your-bot-token-here', 'SLACK_BOT_TOKEN');
SELECT vault.create_secret('your-signing-secret-here', 'SLACK_SIGNING_SECRET');
```

> **Warning:** Don't use the SQL method in production — the plaintext values will appear in statement logs.

---

## Step 4: Deploy the Proxy

Slack sends webhooks as `application/x-www-form-urlencoded`, but PostgREST's RPC endpoint needs `text/plain` to pass the raw body to the PL/pgSQL function. The proxy bridges this gap. Choose **one** of the two options below.

### Option A: Cloudflare Worker

1. Install dependencies:
   ```bash
   cd worker
   npm install
   ```

2. Authenticate with Cloudflare:
   ```bash
   npx wrangler login
   ```

3. Set the secrets:
   ```bash
   npx wrangler secret put SUPABASE_URL
   # Enter: https://<your-project-ref>.supabase.co

   npx wrangler secret put SUPABASE_SERVICE_ROLE_KEY
   # Enter: your service role key (find in Supabase Dashboard → Settings → API)
   ```

4. Deploy:
   ```bash
   npm run deploy
   ```

5. Note the deployed URL (e.g. `https://capacity-request-slack-proxy.<your-account>.workers.dev`)

### Option B: Supabase Edge Function

1. Deploy the function:
   ```bash
   supabase functions deploy slack-proxy
   ```

2. The function URL will be:
   ```
   https://<your-project-ref>.supabase.co/functions/v1/slack-proxy
   ```

   For local development:
   ```
   http://127.0.0.1:54321/functions/v1/slack-proxy
   ```

   The Edge Function reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the environment automatically.

---

## Step 5: Update the Slack App URLs

Now that the proxy is deployed, point Slack to it.

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps) and select your app
2. In the left sidebar, click **Slash Commands**
   - Click the pencil icon next to `/capacity`
   - Set **Request URL** to your proxy URL from Step 4
   - Click **Save**
3. In the left sidebar, click **Interactivity & Shortcuts**
   - Set **Request URL** to the same proxy URL
   - Click **Save Changes**

---

## Step 6: Invite the Bot to a Channel

The bot needs to be in a channel to post messages.

1. Open Slack and go to the channel where you want capacity request notifications
2. Type `/invite @Capacity Request` or click the channel name → **Integrations** → **Add apps**
3. Note the channel ID (right-click the channel name → **Copy link**, the ID is the last path segment starting with `C`)

When creating capacity requests via the API, pass this channel ID as the `slack_channel_id` on the `capacity_requests` row to receive notifications there.

---

## Step 7: Test the Integration

### Test the slash command

In your Slack channel, type:
```
/capacity hello
```

You should see a response: "Slash command received. Use the API to create requests."

### Test the full workflow via API

```bash
# Set your Supabase URL and service role key
SUPABASE_URL="https://<your-project-ref>.supabase.co"
SERVICE_ROLE_KEY="<your-service-role-key>"

# Create a capacity request
curl -X POST "$SUPABASE_URL/rest/v1/rpc/create_capacity_request" \
  -H "Content-Type: application/json" \
  -H "apikey: $SERVICE_ROLE_KEY" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -d '{
    "p_requester_user_id": "U_test",
    "p_commercial_owner_user_id": "U_commercial",
    "p_infra_owner_group": "infra-team",
    "p_customer_ref": {"org_id": "org_test", "name": "Test Corp"},
    "p_requested_size": "32XL",
    "p_quantity": 2,
    "p_region": "us-east-1",
    "p_needed_by_date": "2026-03-01",
    "p_expected_duration_days": 90
  }'
```

This returns the created request (in `UNDER_REVIEW` state). If a `slack_channel_id` is set on the row, you'll see a Slack notification in that channel.

### Run the SQL test suite

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 \
  -f test/test_workflow.sql
```

All 15 tests should pass.

---

## Troubleshooting

### "Missing Slack signature headers" error
The request is hitting PostgREST directly without going through the proxy. Make sure Slack's Request URL points to the proxy, not directly to Supabase.

### "Invalid Slack signature" error
The signing secret in Vault doesn't match your Slack app. Verify the `SLACK_SIGNING_SECRET` value in Vault matches what's shown in **Basic Information → App Credentials**.

### "Slack request timestamp too old" error
The request is more than 5 minutes old. This is the replay protection check. If testing manually, make sure your system clock is accurate.

### Bot messages not appearing in Slack
- Verify the bot is invited to the channel
- Verify `SLACK_BOT_TOKEN` in Vault is correct and starts with `xoxb-`
- Check `net._http_response` for failed pg_net requests:
  ```sql
  SELECT id, url, status_code, content
  FROM net._http_response
  WHERE status_code >= 400 OR status_code IS NULL
  ORDER BY created DESC
  LIMIT 10;
  ```

### Interactive buttons not working
Make sure **Interactivity** is enabled in your Slack app settings and the Request URL points to your proxy.
