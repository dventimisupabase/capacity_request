# Setup Guide: Capacity Request Workflow

This guide walks through setting up the Slack app, deploying the proxy, and connecting everything to Supabase.

## Prerequisites

- A Supabase project (local or hosted) with all migrations applied
- A Slack workspace where you have permission to install apps
- Supabase CLI installed (`supabase` command available)

---

## Step 1: Create the Slack App

1. Go to [https://api.slack.com/apps](https://api.slack.com/apps)
2. Click **Create New App**
3. Choose **From scratch**
4. Set the app name to **CapReq** and select your workspace
5. Click **Create App**

You now have a Slack app. Don't close this page — you'll need it for the next steps.

---

## Step 2: Configure Display Information

1. In the left sidebar, click **Basic Information**
2. Scroll to **Display Information** and fill in:

| Field               | Value                                                    |
|---------------------|----------------------------------------------------------|
| **App name**        | `CapReq`                                                 |
| **Short description** | `Manage infrastructure capacity requests with approvals` |
| **Background color** | `#0f1923`                                               |
| **App icon**        | Upload `www/capreq-icon.png` from this repo (512x512)    |

3. Set the **Long description** to:

```
CapReq streamlines infrastructure capacity request management directly from Slack.

Create requests via /capacity or a guided modal form with dropdowns for size, region, and dates. Track requests through a multi-stage approval workflow: commercial review, technical review, optional VP escalation for high-cost requests, customer confirmation, and provisioning.

Features:
- Interactive Block Kit messages with contextual approve/reject buttons
- Multi-stage approval workflow (commercial, technical, VP, customer)
- Automatic VP escalation for requests above cost thresholds
- /capacity list, /capacity view, and /capacity help commands
- Real-time status updates that replace messages in-place
- Threaded notifications for each request
```

4. Click **Save Changes**

---

## Step 3: Configure Bot Scopes

1. In the left sidebar, click **OAuth & Permissions**
2. Scroll to **Scopes → Bot Token Scopes**
3. Add these scopes:

| Scope              | Purpose                                    |
|--------------------|--------------------------------------------|
| `chat:write`       | Post Block Kit messages to channels        |
| `commands`         | Register the `/capacity` slash command     |

---

## Step 4: Configure the Slash Command

1. In the left sidebar, click **Slash Commands**
2. Click **Create New Command**
3. Fill in:

| Field              | Value                                                              |
|--------------------|--------------------------------------------------------------------|
| **Command**        | `/capacity`                                                        |
| **Request URL**    | `https://<your-project-ref>.supabase.co/functions/v1/slack-proxy`  |
| **Short Description** | `Manage capacity requests`                                      |
| **Usage Hint**     | `[create | list | view <id> | help]`                               |

4. Click **Save**

> The Request URL will be set in Step 8 after deploying the edge function. You can use a placeholder for now and update it later.

---

## Step 5: Enable Interactivity

This is required for interactive buttons (approve/reject/cancel) and the modal creation form.

1. In the left sidebar, click **Interactivity & Shortcuts**
2. Toggle **Interactivity** to **On**
3. Set **Request URL** to the **same URL** as the slash command:
   ```
   https://<your-project-ref>.supabase.co/functions/v1/slack-proxy
   ```
4. Click **Save Changes**

> **Important:** The Interactivity URL and Slash Command URL must both point to the same edge function. If the Interactivity URL is missing or wrong, modal submissions will hang (beachball) and button clicks will silently fail.

---

## Step 6: Install to Workspace and Collect Credentials

### Install

1. In the left sidebar, click **OAuth & Permissions**
2. Click **Install to Workspace** (or **Reinstall to Workspace** if updating)
3. Authorize the app when prompted
4. Copy the **Bot User OAuth Token** — it starts with `xoxb-`

### Signing Secret

1. In the left sidebar, click **Basic Information**
2. Scroll to **App Credentials**
3. Click **Show** next to **Signing Secret** and copy it

You now have two credentials:
- **Bot Token**: `xoxb-...` (for posting messages and opening modals)
- **Signing Secret**: a hex string (for verifying webhook authenticity)

---

## Step 7: Store Secrets

Secrets need to be stored in **two places**: Supabase Vault (for database functions) and edge function environment (for the proxy).

### Supabase Vault (used by database functions)

The database functions `process_outbox()` and `verify_slack_signature()` read tokens from Vault at runtime.

**Via the Supabase Dashboard (recommended):**

1. Go to your Supabase project dashboard
2. Navigate to **Settings → Vault**
3. Click **Add new secret** and create these two secrets:

| Name                   | Value                                    |
|------------------------|------------------------------------------|
| `SLACK_BOT_TOKEN`      | The `xoxb-...` token from Step 6         |
| `SLACK_SIGNING_SECRET`  | The signing secret from Step 6           |

**Via SQL (local development only):**

```sql
SELECT vault.create_secret('xoxb-your-bot-token-here', 'SLACK_BOT_TOKEN');
SELECT vault.create_secret('your-signing-secret-here', 'SLACK_SIGNING_SECRET');
```

> **Warning:** Don't use the SQL method in production — plaintext values will appear in statement logs.

### Edge Function Environment (used by the proxy for modal opening)

The edge function needs `SLACK_BOT_TOKEN` to call Slack's `views.open` API (for the modal creation form). `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically.

```bash
supabase secrets set SLACK_BOT_TOKEN=xoxb-your-bot-token-here
```

> **Important:** The Vault token and the edge function env token must be the **same** `xoxb-` value. If they differ, the modal will open but outbox-delivered messages will fail with `invalid_auth`.

---

## Step 8: Deploy the Edge Function

```bash
supabase functions deploy slack-proxy --no-verify-jwt
```

The `--no-verify-jwt` flag is **required** because Slack sends webhooks without a Supabase JWT. Security is provided by HMAC-SHA256 signature verification in the database function instead.

The function URL will be:
```
https://<your-project-ref>.supabase.co/functions/v1/slack-proxy
```

If you used a placeholder in Steps 4 and 5, go back and update:
- **Slash Commands** → `/capacity` → **Request URL**
- **Interactivity & Shortcuts** → **Request URL**

Both should point to the same edge function URL above.

---

## Step 9: Apply Database Migrations

```bash
supabase db push
```

Or for local development:
```bash
supabase db reset
```

---

## Step 10: Invite the Bot to a Channel

The bot must be a member of any channel where it needs to post messages.

1. Open Slack and go to the channel for capacity request notifications
2. Type `/invite @CapReq` or click the channel name → **Integrations** → **Add apps**
3. Note the channel ID (right-click the channel name → **Copy link** — the ID is the last path segment starting with `C`)

> **Important:** If the bot is not in the channel, outbox messages will fail silently. Check `net._http_response` for `not_in_channel` errors if messages aren't appearing.

---

## Step 11: Test the Integration

### Test the slash command

In your Slack channel, type:
```
/capacity help
```

You should see an ephemeral message listing available commands.

### Test the modal

Type:
```
/capacity
```

A modal dialog should open with fields for size, region, quantity, duration, needed by date, and optional fields for cost, customer, commercial owner, and infrastructure group. Fill it out and submit — a Block Kit message with interactive buttons should appear in the channel.

### Test interactive buttons

Click **Commercial Approve** on the Block Kit message. The message should update in-place showing "Commercial: Approved" with the Commercial Approve/Reject buttons removed and Tech Approve/Reject buttons remaining.

### Test slash command subcommands

```
/capacity list          # Shows your recent requests
/capacity view CR-2026-000001  # Shows request details with action buttons
```

### Run the SQL test suite

```bash
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 \
  -f test/test_workflow.sql
```

All 49 tests should pass.

---

## Troubleshooting

### Edge function returns 401 Unauthorized

The function was deployed without `--no-verify-jwt`. Redeploy:
```bash
supabase functions deploy slack-proxy --no-verify-jwt
```

### Modal submission hangs (beachball) then form reappears

The **Interactivity & Shortcuts** Request URL is not configured or points to the wrong URL. It must point to the same edge function URL as the slash command. Go to **Interactivity & Shortcuts** in your Slack app settings and verify the URL.

### Modal submits but no Block Kit message appears in channel

Check these in order:

1. **Bot not in channel:** Invite the bot with `/invite @CapReq`
2. **Wrong Vault token:** The `SLACK_BOT_TOKEN` in Vault must match the one in the edge function env. Check `net._http_response` for `invalid_auth` errors:
   ```sql
   SELECT id, status_code, content
   FROM net._http_response
   ORDER BY id DESC
   LIMIT 5;
   ```
3. **Outbox not processing:** Check that the `process-outbox` cron job is running:
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'process-outbox';
   ```

### "Invalid Slack signature" error

The signing secret in Vault doesn't match your Slack app. Verify the `SLACK_SIGNING_SECRET` value in Vault matches what's shown in **Basic Information → App Credentials**.

### "Slack request timestamp too old" error

The request is more than 5 minutes old (replay protection). If testing manually, make sure your system clock is accurate.

### Button clicks don't update the message

- Verify **Interactivity** is toggled **On** in your Slack app settings
- Verify the Interactivity **Request URL** points to your edge function
- Check edge function logs in the Supabase Dashboard → **Functions → slack-proxy → Logs**

### Duplicate messages appearing after button clicks

The `dispatch_side_effects()` function should check `app.suppress_outbox`. Verify migration `20260216000005_suppress_interactive_outbox.sql` has been applied:
```bash
supabase db push
```

### "Missing Slack signature headers" error

The request is hitting PostgREST directly without going through the proxy. Make sure Slack's Request URL points to the edge function, not directly to Supabase's REST API.
