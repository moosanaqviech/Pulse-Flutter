import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { stripe} from "../shared/stripe-client";
import { REGIONS, MEMORY, TIMEOUTS} from "../shared/constants";


export const createPaymentIntentWithSetup = onCall(
  {
    region: REGIONS.PRIMARY,
    memory: MEMORY.MEDIUM,
    timeoutSeconds: TIMEOUTS.MEDIUM,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be authenticated");
    }

    const { dealId, userId, purchaseId, amount, currency, setupFutureUsage } = request.data;

    if (!dealId || !purchaseId || !amount) {
      throw new HttpsError("invalid-argument", "dealId, purchaseId, and amount required");
    }

    // Get deal and business
    const dealDoc = await admin.firestore().collection("deals").doc(dealId).get();
    if (!dealDoc.exists) {
      throw new HttpsError("not-found", "Deal not found");
    }

    const deal = dealDoc.data()!;
    const businessId = deal.businessId;

    const businessDoc = await admin.firestore().collection("businesses").doc(businessId).get();
    if (!businessDoc.exists) {
      throw new HttpsError("not-found", "Business not found");
    }

    const business = businessDoc.data()!;
    const connectedAccountId = business.stripeConnectedAccountId;

    if (!connectedAccountId || !business.stripeAccountOnboarded) {
      throw new HttpsError("failed-precondition", "Business payment setup incomplete");
    }

    // Get or create customer
    const userDoc = await admin.firestore().collection("users").doc(userId).get();
    const userData = userDoc.data();
    let customerId = userData?.stripeCustomerId;

    if (!customerId) {
      const customer = await stripe.customers.create({
        email: userData?.email || request.auth.token.email || "unknown",
        metadata: { userId: userId },
      });
      customerId = customer.id;
      await admin.firestore().collection("users").doc(userId).update({
        stripeCustomerId: customerId,
      });
    }

    // Calculate fees (12% platform fee)
    const expectedAmount = Math.round(amount * 100);
    const platformFeeAmount = Math.round(expectedAmount * 0.12);

    // Create Payment Intent with Connect
    const paymentIntent = await stripe.paymentIntents.create({
      amount: expectedAmount,
      currency: currency || "cad",
      customer: customerId,
      setup_future_usage: setupFutureUsage ? "off_session" : undefined,
      metadata: {
        userId,
        dealId,
        purchaseId,
        businessId,
        platformFee: (platformFeeAmount / 100).toFixed(2),
      },
      description: `${deal.title} at ${deal.businessName}`,
      application_fee_amount: platformFeeAmount,
      transfer_data: {
        destination: connectedAccountId,
      },
    });

    // Reserve inventory
    await admin.firestore().collection("deals").doc(dealId).update({
      remainingQuantity: admin.firestore.FieldValue.increment(-1),
    });

    await admin.firestore().collection("purchases").doc(purchaseId).update({
      stripePaymentIntentId: paymentIntent.id,
    });

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  }
);