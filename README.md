# Convex Salesforce Connector

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Convex](https://img.shields.io/badge/Powered%20by-Convex-FF6B35.svg)](https://convex.dev)
[![Salesforce](https://img.shields.io/badge/Salesforce-CDC-00A1E0.svg)](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-blue.svg)](https://www.typescriptlang.org/)
[![npm version](https://img.shields.io/npm/v/convex-salesforce-connector.svg)](https://www.npmjs.com/package/convex-salesforce-connector)
[![CI](https://github.com/adamanz/convex-salesforce-connector/actions/workflows/ci.yml/badge.svg)](https://github.com/adamanz/convex-salesforce-connector/actions/workflows/ci.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

<!-- Salesforce Package Install -->
<a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcM9AAK">
  <img src="https://img.shields.io/badge/Install%20in-Production-blue.svg?logo=salesforce" alt="Install in Salesforce Production"/>
</a>
<a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcM9AAK">
  <img src="https://img.shields.io/badge/Install%20in-Sandbox-green.svg?logo=salesforce" alt="Install in Salesforce Sandbox"/>
</a>

---

**Real-time bidirectional sync between Salesforce and Convex using Change Data Capture (CDC).**

Sync any Salesforce object to Convex in real-time. React to changes with serverless functions. Build modern apps on top of your CRM data.

## Features

- **Real-time sync** - Salesforce CDC triggers push changes instantly to Convex
- **Any object** - Sync standard objects, custom objects, or both
- **Bidirectional** - Read from Convex, write back to Salesforce
- **Type-safe** - Full TypeScript support with generated types
- **Setup wizard** - Interactive CLI to configure everything
- **Flexible config** - Easily customize which fields to sync

## Quick Start

### Option 1: Setup Wizard (Recommended)

```bash
# Clone the repo
git clone https://github.com/adamanz/convex-salesforce-connector.git
cd convex-salesforce-connector

# Install dependencies
npm install

# Run the interactive setup wizard
npm run setup
```

The wizard **automatically handles everything**:
1. Connects to Convex and Salesforce
2. Lets you select objects to sync
3. Deploys CDC triggers to Salesforce
4. **Auto-configures all Convex environment variables** (no manual copy/paste!)
5. Generates and syncs webhook secret between SF and Convex
6. Runs initial data sync

For auth, choose:
- **Quick Setup**: Uses SF CLI session (expires in 2hrs, good for dev)
- **Production Setup**: OAuth with auto-refresh (set it and forget it)

### Option 2: Manual Setup

#### 1. Clone & Install

```bash
git clone https://github.com/adamanz/convex-salesforce-connector.git
cd convex-salesforce-connector
npm install
```

#### 2. Setup Convex

```bash
npx convex dev
# Note your deployment URL (e.g., https://your-project-123.convex.site)
```

#### 3. Configure Environment

```bash
cp .env.example .env.local
```

Edit `.env.local`:
```env
SALESFORCE_ACCESS_TOKEN=your_access_token
SALESFORCE_INSTANCE_URL=https://your-instance.salesforce.com
```

#### 4. Update Webhook URL

Edit `salesforce/force-app/main/default/classes/ConvexCDCService.cls`:
```apex
private static final String CONVEX_WEBHOOK_URL = 'https://YOUR_DEPLOYMENT.convex.site/webhooks/salesforce/cdc';
```

#### 5. Deploy to Salesforce

```bash
# Login to your org
sf org login web -a MySalesforceOrg

# Deploy
sf project deploy start -d salesforce/force-app -o MySalesforceOrg
```

#### 6. Enable CDC

In Salesforce Setup:
1. Go to **Setup → Integrations → Change Data Capture**
2. Select objects to sync (Account, Contact, Lead, Opportunity, etc.)
3. Save

#### 7. Initial Sync

```bash
npx convex run salesforce:syncAll
```

## Salesforce Package Installation

For the easiest Salesforce deployment, install our unlocked package:

| Environment | Install Link |
|------------|--------------|
| Production | [Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcM9AAK) |
| Sandbox | [Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcM9AAK) |

After installing:
1. Go to the **Convex Setup** tab in Salesforce
2. Follow the setup wizard to configure your webhook URL and secret
3. Enable CDC for your desired objects

## Architecture

```
┌─────────────────┐     CDC Event      ┌──────────────────┐
│   Salesforce    │ ─────────────────► │      Convex      │
│                 │                    │                  │
│  ┌───────────┐  │   HTTP POST        │  ┌────────────┐  │
│  │CDC Trigger│──┼───────────────────►│  │  Webhook   │  │
│  └───────────┘  │                    │  │  Handler   │  │
│        │        │                    │  └─────┬──────┘  │
│        ▼        │                    │        │         │
│  ┌───────────┐  │                    │        ▼         │
│  │   Apex    │  │                    │  ┌────────────┐  │
│  │  Service  │  │                    │  │   Mirror   │  │
│  └───────────┘  │                    │  │   Tables   │  │
│                 │                    │  └────────────┘  │
│                 │    REST API        │        │         │
│                 │ ◄──────────────────│        ▼         │
│                 │                    │  ┌────────────┐  │
│                 │                    │  │  Your App  │  │
└─────────────────┘                    └──────────────────┘
```

## Authentication & Environments

### Authentication Flow

The connector uses two authentication mechanisms:

**1. Salesforce → Convex (Webhook Security)**
- HMAC-SHA256 signature on all CDC webhook payloads
- Shared secret stored in Salesforce Custom Metadata & Convex env vars
- Timestamp validation prevents replay attacks

**2. Convex → Salesforce (OAuth 2.0)**
- Connected App with OAuth 2.0 + refresh token flow
- Tokens auto-refresh before expiry (no manual intervention)
- Credentials stored securely in Convex environment variables

### Environment Setup

**Development vs Production Convex**

```bash
# Development (Convex dev deployment)
npx convex dev
# Webhook URL: https://your-project-123.convex.cloud/webhooks/salesforce/cdc

# Production (Convex production deployment)
npx convex deploy
# Webhook URL: https://your-project-123.convex.site/webhooks/salesforce/cdc
```

**Environment Variables (Convex)**

The setup wizard configures these automatically via `npx convex env set`:

| Variable | Description | Auto-configured? |
|----------|-------------|------------------|
| `SALESFORCE_INSTANCE_URL` | Your Salesforce org URL | ✅ Yes |
| `SALESFORCE_WEBHOOK_SECRET` | HMAC secret for webhooks | ✅ Yes |
| `SALESFORCE_ACCESS_TOKEN` | Session or OAuth access token | ✅ Yes |
| `SALESFORCE_REFRESH_TOKEN` | OAuth refresh token (production) | ✅ Yes |
| `SALESFORCE_CLIENT_ID` | Connected App key (production) | ✅ Yes |
| `SALESFORCE_CLIENT_SECRET` | Connected App secret (production) | ✅ Yes |

> **Note**: If you need to set these manually, use `npx convex env set VAR_NAME "value"`

**Salesforce Sandbox vs Production**

Use different Custom Metadata values per environment:
- In **Sandbox**: Configure `Convex_Connector_Settings__mdt` with dev Convex URL
- In **Production**: Configure with production Convex URL

The setup wizard helps configure these values per environment.

### Generating Webhook Secret

```bash
# Generate a secure 32-character hex secret
openssl rand -hex 32
```

Use the same secret in:
1. Convex environment variable: `SALESFORCE_WEBHOOK_SECRET`
2. Salesforce Custom Metadata: `Webhook_Secret__c`

## Configuration

### Adding Custom Objects

Edit `convex/config.ts` to add your custom objects:

```typescript
SALESFORCE_OBJECTS.push({
  apiName: "MyCustomObject__c",
  tableName: "sfMyCustomObjects",
  label: "My Custom Objects",
  enabled: true,
  fields: [
    { apiName: "Name", convexName: "name", type: "string", required: true },
    { apiName: "Custom_Field__c", convexName: "customField", type: "string" },
    // Add more fields...
  ],
});
```

Then generate the trigger:

```bash
npm run generate:trigger MyCustomObject__c
```

### Customizing Field Mappings

Each field configuration supports:
- `apiName` - Salesforce API field name
- `convexName` - Name to use in Convex
- `type` - Data type (`string`, `number`, `boolean`, `date`, `datetime`, `any`)
- `required` - Whether the field is required
- `index` - Create an index for faster queries

## Usage

### Query Synced Data

```typescript
// convex/myFunctions.ts
import { query } from "./_generated/server";

export const getContacts = query({
  handler: async (ctx) => {
    return await ctx.db.query("sfContacts").collect();
  },
});

export const getContactByEmail = query({
  args: { email: v.string() },
  handler: async (ctx, { email }) => {
    return await ctx.db
      .query("sfContacts")
      .withIndex("by_email", (q) => q.eq("email", email))
      .first();
  },
});
```

### Write Back to Salesforce

```typescript
// convex/myFunctions.ts
import { action } from "./_generated/server";
import { api } from "./_generated/api";

export const updateContactEmail = action({
  args: { contactId: v.string(), email: v.string() },
  handler: async (ctx, { contactId, email }) => {
    return await ctx.runAction(api.salesforce.updateRecord, {
      objectType: "Contact",
      recordId: contactId,
      fields: { Email: email },
    });
  },
});
```

### React to Changes

```typescript
// convex/myFunctions.ts
import { internalMutation } from "./_generated/server";

// This could be called from a scheduled job or triggered by your app
export const onOpportunityWon = internalMutation({
  args: { opportunityId: v.string() },
  handler: async (ctx, { opportunityId }) => {
    const opp = await ctx.db
      .query("sfOpportunities")
      .withIndex("by_sfId", (q) => q.eq("sfId", opportunityId))
      .first();

    if (opp?.stageName === "Closed Won") {
      // Your business logic here
      console.log(`Opportunity ${opp.name} closed won for $${opp.amount}`);
    }
  },
});
```

## API Reference

### Convex Functions

| Function | Type | Description |
|----------|------|-------------|
| `salesforce:processCdcEvent` | action | Process single CDC event |
| `salesforce:processCdcBatch` | action | Process batch of CDC events |
| `salesforce:bulkSync` | action | Sync specific object type |
| `salesforce:syncAll` | action | Sync all enabled objects |
| `salesforce:getSyncStats` | query | Get sync statistics |
| `salesforce:getConfig` | query | Get current configuration |
| `salesforce:updateRecord` | action | Update Salesforce record |
| `salesforce:query` | action | Run SOQL query |

### Webhook Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/webhooks/salesforce/cdc` | POST | Receive CDC events |
| `/webhooks/salesforce/cdc/status` | GET | Check sync status |
| `/webhooks/salesforce/config` | GET | Get configuration |
| `/health` | GET | Health check |

## CLI Commands

```bash
npm run setup              # Interactive setup wizard
npm run dev                # Start Convex dev server
npm run sync               # Full sync from Salesforce
npm run status             # Check sync statistics
npm run deploy:convex      # Deploy Convex functions
npm run deploy:salesforce  # Deploy to Salesforce
npm run test:salesforce    # Run Apex tests
npm run generate:trigger   # Generate CDC trigger for object
```

## Troubleshooting

### Events not syncing

1. Check CDC is enabled in Salesforce Setup → Change Data Capture
2. Verify webhook URL in `ConvexCDCService.cls`
3. Add Remote Site Setting for your Convex URL
4. Check Convex logs: `npx convex logs`

### Authentication errors

```bash
# Refresh Salesforce token
sf org login web -a MySalesforceOrg

# Get new access token
sf org display -o MySalesforceOrg --json | jq -r '.result.accessToken'
```

### Debugging

Enable debug logs in Salesforce:
1. Setup → Debug Logs
2. Add your user
3. Trigger a change and view logs

Check Convex logs:
```bash
npx convex logs --follow
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Convex](https://convex.dev) - Serverless database and backend
- [Salesforce CDC](https://developer.salesforce.com/docs/atlas.en-us.change_data_capture.meta/change_data_capture) - Change Data Capture

---

**Built with ❤️ for the Convex and Salesforce communities**
