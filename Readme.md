# Pechkin

[![Gem](https://img.shields.io/gem/v/pechkin.svg)](https://rubygems.org/gems/pechkin)

# What is Pechkin?

Pechkin is a simple and powerful tool that acts as a bridge between your services and messengers like **Telegram** and **Slack**. It receives data via HTTP webhooks, transforms it using templates, and sends beautiful messages to your work channels.

Think of it as a "Postman" for your automated notifications.

### Key Features
*   **Admin UI**: Manage bots, channels, and templates via a friendly web interface.
*   **Database Support**: Configurations are stored in a SQLite database by default.
*   **Hot Reload**: Any changes in the Admin UI are applied immediately without restarting the server.
*   **Templates**: Use ERB to render JSON data into human-readable messages.
*   **Flexible Configuration**: Still supports YAML files if you prefer them.
*   **Metrics**: Built-in Prometheus metrics support.

---

# Table of Contents
- [Getting Started](#getting-started)
- [Admin Panel](#admin-panel)
- [1. How to create a Bot](#1-how-to-create-a-bot)
- [2. How to create a Template (View)](#2-how-to-create-a-template-view)
- [3. How to create a Channel and Message](#3-how-to-create-a-channel-and-message)
- [4. How to call cURL and verify](#4-how-to-call-curl-and-verify)
- [Migration from Files](#migration-from-files)
- [Advanced Configuration](#advanced-configuration)
  - [Environment Variables](#environment-variables)
  - [Authorization](#authorization)
  - [Filtering Messages](#filtering-messages)
  - [Connector Specific Parameters](#connector-specific-parameters)
  - [Metrics](#metrics)
- [CLI Options](#cli-options)

---

# Getting Started

### Installation
Install Pechkin as a Ruby gem:
```bash
gem install pechkin
```

### Running the Server
Start Pechkin by specifying a configuration directory:
```bash
pechkin -c . --port 8080
```
By default, Pechkin will create a `pechkin.sqlite3` file in your current folder to store your settings.

---

# Admin Panel

Once Pechkin is running, you can access the **Admin Panel** at:
`http://localhost:8080/admin`

From here, you can manage all your settings visually. Any changes you make are applied "on the fly".

---

# 1. How to create a Bot

A Bot is the identity Pechkin uses to talk to Telegram or Slack.

1.  Open the Admin Panel and go to **Bots**.
2.  Click **Add New Bot**.
3.  **Name**: Give it a simple name (e.g., `notificator`).
4.  **Token**: Paste your API token (from @BotFather for Telegram or Slack App settings).
5.  **Connector**: Choose `telegram` or `slack`.
6.  Click **Create Bot**.

---

# 2. How to create a Template (View)

Templates define how your messages look. They use the **ERB** (Embedded Ruby) format.

1.  Go to **Views** in the Admin Panel.
2.  Click **Add New View**.
3.  **Name**: Give it a name ending in `.erb` (e.g., `alert.erb`).
4.  **ERB Content**: Write your message. Use `<%= ... %>` to insert data from the incoming JSON.
    *   Example: `New order from <%= customer_name %> for $<%= amount %>!`
5.  Click **Create View**.

---

# 3. How to create a Channel and Message

### Step A: Create a Channel
A **Channel** represents a destination (like a specific group or chat).

1.  Go to **Channels** and click **Add New Channel**.
2.  **Name**: The ID of your channel (used in the URL, e.g., `sales-team`).
3.  **Bot**: Select the bot you created in step 1.
4.  **Chat IDs**: Enter where to send the message (e.g., `#sales` for Slack or a chat ID for Telegram).
5.  Click **Create Channel**.

### Step B: Add a Message to the Channel
A **Message** is a specific "endpoint" within your channel.

1.  In the Channels list, find your new channel and click **Add Message**.
2.  **Message Name (ID)**: Give it an ID (e.g., `new-order`).
3.  **Template (View)**: Select the template you created in step 2.
4.  Click **Create Message**.

---

# 4. How to call cURL and verify

Now your webhook is ready! The URL structure is:
`http://localhost:8080/CHANNEL_ID/MESSAGE_ID`

Example: `http://localhost:8080/sales-team/new-order`

### Test it with cURL:
Run this command in your terminal:
```bash
curl -X POST -H 'Content-Type: application/json' \
     -d '{"customer_name": "Alice", "amount": 99}' \
     http://localhost:8080/sales-team/new-order
```
Your bot will send the rendered message to the configured destination!

---

# Migration from Files

If you have existing configuration files (in `bots/`, `views/`, and `channels/` folders), you can import them into the database:

1.  Go to the **Migration** tab in the Admin Panel.
2.  Review the detected files.
3.  Click **Import Files to Database**.

Settings in the database have priority over files and will be used if names conflict.

---

# Advanced Configuration

### Environment Variables
*   `PECHKIN_DB_PATH`: Path to the SQLite file (default: `pechkin.sqlite3`).
*   `DATABASE_URL`: Full connection string for other databases (PostgreSQL, MySQL, etc.).
*   `PORT`: The port the server listens on (default: 8080).

### Authorization
Protect your webhooks using Basic Auth with `.htpasswd` files.
Manage users via the CLI:
```bash
pechkin --add-auth user:password
```

### Filtering Messages
You can skip some requests based on their content using `allow` or `forbid` rules in the **Additional Config** (JSON) field:
```json
{
  "allow": [{"branch": "master"}]
}
```
This will only process requests where the `branch` field in the JSON is `master`.

### Connector Specific Parameters

**Telegram**:
* `telegram_parse_mode`: `markdown` or `html` mode for Telegram messages.

**Slack**:
* `slack_attachments`: Description of attachments to use with Slack messages. See [Slack documentation](https://api.slack.com/docs/message-attachments) for details.

### Metrics
Pechkin exposes Prometheus metrics at `/metrics`.
* `pechkin_start_time_seconds`: Startup timestamp.
* `pechkin_version`: Current version info.

---

# CLI Options

```bash
Usage: pechkin [options]
    -c, --config-dir FILE            Path to configuration directory
        --port PORT                  Server port
        --address ADDRESS            Host address to bind to
    -l, --[no-]list                  List all endpoints
    -k, --[no-]check                 Check configuration for errors
    -s, --send ENDPOINT              Send data to specified ENDPOINT and exit.
```

# License
MIT
