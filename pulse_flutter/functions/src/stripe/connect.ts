import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { stripe} from "../shared/stripe-client";
import { 
  verifyBusinessOwnership, 
  checkRateLimit, 
  requireAuth,
  verifyBusinessEmail,
  verifyBusinessName 
} from "../shared/auth";
import { REGIONS, MEMORY, TIMEOUTS, RATE_LIMITS } from "../shared/constants";

export const createConnectedAccount = onCall(
  {
    region: REGIONS.PRIMARY,
    memory: MEMORY.SMALL,
    timeoutSeconds: TIMEOUTS.SHORT,
  },
  async (request) => {
    const userId = requireAuth(request.auth);
    const { businessId, email, businessName, country, type } = request.data;

    // Validation
    if (!businessId || !email || !businessName) {
      throw new HttpsError(
        "invalid-argument",
        "businessId, email, and businessName are required"
      );
    }

    // Rate limiting
    const allowed = await checkRateLimit(
      userId,
      "stripe_account_create",
      RATE_LIMITS.STRIPE_ACCOUNT_CREATE.maxAttempts,
      RATE_LIMITS.STRIPE_ACCOUNT_CREATE.windowMinutes
    );
    
    if (!allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many attempts. Please try again in an hour."
      );
    }

    // Security checks
    await verifyBusinessOwnership(businessId, userId);
    await verifyBusinessEmail(businessId, email);
    await verifyBusinessName(businessId, businessName);

    // Create account
    const account = await stripe.accounts.create({
      type: type || "express",
      country: country || "CA",
      email: email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      business_type: "company",
      company: { name: businessName },
      metadata: { businessId, platform: "pulse" },
    });

    await admin.firestore().collection("businesses").doc(businessId).update({
      stripeConnectedAccountId: account.id,
      stripeAccountStatus: "pending",
      stripeAccountOnboarded: false,
      stripePayoutsEnabled: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      accountId: account.id,
    };
  }
);

export const createAccountLink = onCall(
  { region: REGIONS.PRIMARY, memory: MEMORY.SMALL },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { connectedAccountId, refreshUrl, returnUrl } = request.data;

    if (!connectedAccountId) {
      throw new HttpsError("invalid-argument", "connectedAccountId is required");
    }

    const accountLink = await stripe.accountLinks.create({
      account: connectedAccountId,
      refresh_url: refreshUrl || "pulse://business/stripe-refresh",
      return_url: returnUrl || "pulse://business/stripe-complete",
      type: "account_onboarding",
    });

    return {
      success: true,
      url: accountLink.url,
      expiresAt: accountLink.expires_at,
    };
  }
);

export const getAccountStatus = onCall(
  { region: REGIONS.PRIMARY, memory: MEMORY.SMALL },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { connectedAccountId } = request.data;

    if (!connectedAccountId) {
      throw new HttpsError("invalid-argument", "connectedAccountId is required");
    }

    const account = await stripe.accounts.retrieve(connectedAccountId);

    const businessQuery = await admin
      .firestore()
      .collection("businesses")
      .where("stripeConnectedAccountId", "==", connectedAccountId)
      .limit(1)
      .get();

    if (!businessQuery.empty) {
      const businessDoc = businessQuery.docs[0];
      const updateData: any = {
        stripeAccountOnboarded: account.charges_enabled && account.payouts_enabled,
        stripePayoutsEnabled: account.payouts_enabled,
        stripeAccountStatus: account.charges_enabled ? "active" : "pending",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (account.charges_enabled && account.payouts_enabled) {
        const currentData = businessDoc.data();
        if (!currentData.stripeOnboardingCompletedAt) {
          updateData.stripeOnboardingCompletedAt = admin.firestore.FieldValue.serverTimestamp();
        }
      }

      await businessDoc.ref.update(updateData);
    }

    return {
      success: true,
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      detailsSubmitted: account.details_submitted,
      accountStatus: account.charges_enabled ? "active" : "pending",
    };
  }
);


