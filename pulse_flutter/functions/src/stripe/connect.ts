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
    try {

        console.log("🔵 Function started with data:", request.data);
        
        const userId = requireAuth(request.auth);
        console.log("🔵 User ID:", userId);
        
        const { businessId, email, businessName, country, type } = request.data;
        console.log("🔵 Parsed data:", { businessId, email, businessName, country, type });


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

        console.log("🔵 About to create Stripe account...");
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
    } catch (error){
        console.error("❌ Detailed error:", error);
      console.error("❌ Error stack:", error.stack);
      throw error;
    }
    
  }
);

export const createAccountLink = onCall(
  { region: REGIONS.PRIMARY, memory: MEMORY.SMALL },
  async (request) => {
    try {
      console.log("🔵 === CREATE ACCOUNT LINK STARTED ===");
      console.log("🔵 Request data:", JSON.stringify(request.data));
      
      if (!request.auth) {
        console.log("❌ No auth in createAccountLink");
        throw new HttpsError("unauthenticated", "Must be authenticated");
      }

      const { connectedAccountId, refreshUrl, returnUrl } = request.data;
      console.log("🔵 Extracted data:", { connectedAccountId, refreshUrl, returnUrl });

      if (!connectedAccountId) {
        console.log("❌ Missing connectedAccountId");
        throw new HttpsError("invalid-argument", "connectedAccountId is required");
      }

      // Use the URLs provided by the client (deep links for mobile, web URLs for fallback)
      const finalRefreshUrl = refreshUrl || "https://checkpulse.shop//stripe-refresh";
      const finalReturnUrl = returnUrl || "https://checkpulse.shop/stripe-complete";
      
      console.log("🔵 Using URLs:", { finalRefreshUrl, finalReturnUrl });
      console.log("🔵 About to create Stripe account link...");
      
      const accountLink = await stripe.accountLinks.create({
        account: connectedAccountId,
        refresh_url: finalRefreshUrl,
        return_url: finalReturnUrl,
        type: "account_onboarding",
      });
      
      console.log("✅ Account link created:", accountLink.url);

      return {
        success: true,
        url: accountLink.url,
        expiresAt: accountLink.expires_at,
      };
    } catch (error: any) {
      console.error("❌ === CREATE ACCOUNT LINK ERROR ===");
      console.error("❌ Error:", error);
      console.error("❌ Error message:", error.message);
      console.error("❌ Error stack:", error.stack);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", `Account link failed: ${error.message}`);
    }
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

    // Check if account is restricted
    const isRestricted = account.requirements?.disabled_reason !== null || 
                        (account.requirements?.currently_due && account.requirements.currently_due.length > 0);

    const businessQuery = await admin
      .firestore()
      .collection("businesses")
      .where("stripeConnectedAccountId", "==", connectedAccountId)
      .limit(1)
      .get();

    if (!businessQuery.empty) {
      const businessDoc = businessQuery.docs[0];
      
      // Determine actual status
      let accountStatus = "pending";
      if (isRestricted) {
        accountStatus = "restricted";
      } else if (account.charges_enabled && account.payouts_enabled) {
        accountStatus = "active";
      }

      const updateData: any = {
        stripeAccountOnboarded: account.charges_enabled && account.payouts_enabled && !isRestricted,
        stripePayoutsEnabled: account.payouts_enabled,
        stripeAccountStatus: accountStatus,
        stripeRequirementsCurrentlyDue: account.requirements?.currently_due || [],
        stripeDisabledReason: account.requirements?.disabled_reason || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (account.charges_enabled && account.payouts_enabled && !isRestricted) {
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
      accountStatus: isRestricted ? "restricted" : (account.charges_enabled ? "active" : "pending"),
      isRestricted: isRestricted,
      disabledReason: account.requirements?.disabled_reason,
      currentlyDue: account.requirements?.currently_due || [],
    };
  }
);


