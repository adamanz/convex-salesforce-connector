import { v } from "convex/values";
import { internalMutation, internalAction, internalQuery } from "./_generated/server";

/**
 * Salesforce OAuth Token Management
 *
 * Handles OAuth 2.0 token refresh for Connected App authentication.
 * Tokens are stored in the database and automatically refreshed when expired.
 */

// Token expiry buffer (refresh 5 minutes before expiry)
const EXPIRY_BUFFER_MS = 5 * 60 * 1000;

/**
 * Get valid Salesforce credentials
 * Returns access token, refreshing if needed
 */
export const getCredentials = internalAction({
  args: {},
  returns: v.object({
    accessToken: v.string(),
    instanceUrl: v.string(),
  }),
  handler: async (ctx): Promise<{ accessToken: string; instanceUrl: string }> => {
    // Check for stored token first
    const stored = await ctx.runQuery(internal.auth.getStoredToken, {});

    if (stored && stored.expiresAt > Date.now() + EXPIRY_BUFFER_MS) {
      return {
        accessToken: stored.accessToken,
        instanceUrl: stored.instanceUrl,
      };
    }

    // Check if we have refresh token to get new access token
    if (stored?.refreshToken) {
      const refreshed = await refreshAccessToken(
        stored.refreshToken,
        stored.instanceUrl
      );

      if (refreshed) {
        await ctx.runMutation(internal.auth.storeToken, {
          accessToken: refreshed.accessToken,
          refreshToken: stored.refreshToken,
          instanceUrl: stored.instanceUrl,
          expiresAt: Date.now() + (refreshed.expiresIn * 1000),
        });

        return {
          accessToken: refreshed.accessToken,
          instanceUrl: stored.instanceUrl,
        };
      }
    }

    // Fall back to environment variables (for initial setup or simple auth)
    const accessToken = process.env.SALESFORCE_ACCESS_TOKEN;
    const instanceUrl = process.env.SALESFORCE_INSTANCE_URL;

    if (!accessToken || !instanceUrl) {
      throw new Error(
        "Salesforce credentials not configured. Run 'npm run setup' or set environment variables."
      );
    }

    return { accessToken, instanceUrl };
  },
});

/**
 * Refresh access token using refresh token
 */
async function refreshAccessToken(
  refreshToken: string,
  instanceUrl: string
): Promise<{ accessToken: string; expiresIn: number } | null> {
  const clientId = process.env.SALESFORCE_CLIENT_ID;
  const clientSecret = process.env.SALESFORCE_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    console.warn("OAuth client credentials not configured, cannot refresh token");
    return null;
  }

  try {
    const response = await fetch(`${instanceUrl}/services/oauth2/token`, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("Token refresh failed:", error);
      return null;
    }

    const data = await response.json();
    return {
      accessToken: data.access_token,
      expiresIn: data.expires_in || 7200, // Default 2 hours
    };
  } catch (error: any) {
    console.error("Token refresh error:", error.message);
    return null;
  }
}

/**
 * Store OAuth token in database
 */
export const storeToken = internalMutation({
  args: {
    accessToken: v.string(),
    refreshToken: v.string(),
    instanceUrl: v.string(),
    expiresAt: v.number(),
  },
  handler: async (ctx, args) => {
    // Delete existing token
    const existing = await ctx.db.query("sfAuthTokens").first();
    if (existing) {
      await ctx.db.delete(existing._id);
    }

    // Store new token
    await ctx.db.insert("sfAuthTokens", {
      ...args,
      createdAt: Date.now(),
    });
  },
});

/**
 * Get stored token from database
 */
export const getStoredToken = internalQuery({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("sfAuthTokens").first();
  },
});

/**
 * Initial OAuth flow - exchange auth code for tokens
 * Called after user authorizes the Connected App
 */
export const exchangeAuthCode = internalAction({
  args: {
    code: v.string(),
    redirectUri: v.string(),
  },
  returns: v.object({
    success: v.boolean(),
    error: v.optional(v.string()),
  }),
  handler: async (ctx, { code, redirectUri }): Promise<{ success: boolean; error?: string }> => {
    const clientId = process.env.SALESFORCE_CLIENT_ID;
    const clientSecret = process.env.SALESFORCE_CLIENT_SECRET;

    if (!clientId || !clientSecret) {
      return { success: false, error: "OAuth client credentials not configured" };
    }

    try {
      const response = await fetch("https://login.salesforce.com/services/oauth2/token", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          client_id: clientId,
          client_secret: clientSecret,
          redirect_uri: redirectUri,
          code,
        }),
      });

      if (!response.ok) {
        const error = await response.text();
        return { success: false, error: `OAuth failed: ${error}` };
      }

      const data = await response.json();

      await ctx.runMutation(internal.auth.storeToken, {
        accessToken: data.access_token,
        refreshToken: data.refresh_token,
        instanceUrl: data.instance_url,
        expiresAt: Date.now() + ((data.expires_in || 7200) * 1000),
      });

      return { success: true };
    } catch (error: any) {
      return { success: false, error: error.message };
    }
  },
});

/**
 * Verify HMAC signature from Salesforce webhook
 */
export async function verifyWebhookSignature(
  payload: string,
  signature: string | null,
  timestamp: string | null
): Promise<{ valid: boolean; error?: string }> {
  const secret = process.env.SALESFORCE_WEBHOOK_SECRET;

  // If no secret configured, skip verification (but warn)
  if (!secret) {
    console.warn("SALESFORCE_WEBHOOK_SECRET not set - webhook signature verification disabled");
    return { valid: true };
  }

  if (!signature) {
    return { valid: false, error: "Missing X-Convex-Signature header" };
  }

  if (!timestamp) {
    return { valid: false, error: "Missing X-Convex-Timestamp header" };
  }

  // Check timestamp is within 5 minutes
  const timestampMs = parseInt(timestamp, 10);
  const now = Date.now();
  if (Math.abs(now - timestampMs) > 5 * 60 * 1000) {
    return { valid: false, error: "Request timestamp too old" };
  }

  // Compute expected signature
  const signedPayload = `${timestamp}.${payload}`;
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBytes = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(signedPayload)
  );

  const expectedSignature = Array.from(new Uint8Array(signatureBytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  if (signature !== expectedSignature) {
    return { valid: false, error: "Invalid signature" };
  }

  return { valid: true };
}

// Re-export for internal use
import { internal } from "./_generated/api";
