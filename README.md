# Convex Salesforce Connector

<!-- Salesforce-style badges -->
<p align="center">
  <a href="https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcijAAC">
    <img src="https://img.shields.io/badge/Install%20Package-Production%20Org-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white" alt="Install in Production"/>
  </a>
  &nbsp;
  <a href="https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcijAAC">
    <img src="https://img.shields.io/badge/Install%20Package-Sandbox-00A1E0?style=for-the-badge&logo=salesforce&logoColor=white" alt="Install in Sandbox"/>
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Salesforce-Change%20Data%20Capture-00A1E0?style=flat-square&logo=salesforce&logoColor=white" alt="Salesforce CDC"/>
  <img src="https://img.shields.io/badge/Powered%20by-Convex-FF6B35?style=flat-square&logo=data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjQiIGhlaWdodD0iMjQiIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMTIgMkw0IDdWMTdMIDEyIDIyTDIwIDE3VjdMMTIgMloiIGZpbGw9IndoaXRlIi8+PC9zdmc+&logoColor=white" alt="Powered by Convex"/>
  <img src="https://img.shields.io/badge/Package%20Version-0.3.0-1798c1?style=flat-square" alt="Package Version"/>
  <img src="https://img.shields.io/badge/API%20Version-59.0-1798c1?style=flat-square" alt="API Version"/>
  <img src="https://img.shields.io/badge/OAuth%202.0-PKCE-00A1E0?style=flat-square" alt="OAuth 2.0 PKCE"/>
</p>

<p align="center">
  <a href="https://github.com/adamanz/convex-salesforce-connector/actions/workflows/ci.yml">
    <img src="https://github.com/adamanz/convex-salesforce-connector/actions/workflows/ci.yml/badge.svg" alt="CI"/>
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"/>
  </a>
  <a href="http://makeapullrequest.com">
    <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"/>
  </a>
</p>

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

| Environment | Install Link | Version |
|------------|--------------|---------|
| Production | [Install in Production](https://login.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcijAAC) | v0.3.0 |
| Sandbox | [Install in Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04tfo000001FcijAAC) | v0.3.0 |

After installing:
1. Go to the **Convex Setup** tab in Salesforce
2. Click **Connect with Convex** to start the OAuth 2.0 flow
3. Authorize access to your Convex project (2-click setup!)
4. Enable CDC for your desired objects

### OAuth 2.0 Setup (New in v0.3.0)

Version 0.3.0 introduces a streamlined OAuth 2.0 Authorization Code flow with PKCE.

#### Step 1: Register OAuth Application with Convex

1. Go to [Convex Dashboard](https://dashboard.convex.dev)
2. Navigate to **Settings → OAuth Applications** (or contact Convex to register an OAuth app)
3. Register a new OAuth application:
   - **Name**: Salesforce CDC Connector
   - **Redirect URI**: `https://YOUR_SALESFORCE_DOMAIN.my.salesforce.com/apex/ConvexOAuthCallback`
   - Note down the **Client ID** and **Client Secret**

#### Step 2: Configure OAuth Credentials in Salesforce

1. In Salesforce Setup, search for **Custom Metadata Types**
2. Click **Manage Records** next to **Convex OAuth Settings**
3. Click **New** to create a record:
   - **Label**: Default
   - **Convex OAuth Settings Name**: Default
   - **Client Id**: *(paste from Step 1)*
   - **Client Secret**: *(paste from Step 1)*
   - **Redirect URI**: `https://YOUR_SALESFORCE_DOMAIN.my.salesforce.com/apex/ConvexOAuthCallback`
4. Click **Save**

#### Step 3: Connect to Convex (2 clicks!)

1. Go to the **Convex Setup** tab in Salesforce
2. Click **Connect with Convex**
3. Authorize access on Convex dashboard

The OAuth flow automatically:
- Connects to your Convex team/project
- Generates and syncs webhook secrets
- Configures environment variables
- Sets up the secure connection

#### Before vs After

**Before (7 steps):**
1. Create Convex project manually
2. Copy deployment URL
3. Generate admin API key
4. Paste key into Salesforce
5. Generate webhook secret
6. Configure both systems
7. Test connection

**Now (3 steps + 2 clicks):**
1. Register OAuth app with Convex (one-time)
2. Configure credentials in Salesforce Custom Metadata (one-time)
3. Click "Connect with Convex" → Authorize

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
