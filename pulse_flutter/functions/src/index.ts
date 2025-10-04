// functions/src/index.ts
/* eslint @typescript-eslint/no-var-requires: "off" */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const Stripe = require("stripe");

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Stripe
const getStripeKey = () => {
  const config = functions.config();
  return config.stripe && config.stripe.secret_key ?
    config.stripe.secret_key :
    "TEST";
};

const stripe = new Stripe(getStripeKey(), {
  apiVersion: "2025-09-30.clover",
});

/**
 * Create Payment Intent
 */
exports.createPaymentIntent = functions.https.onCall(async (data: any, context: any) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const dealId = String(data.dealId || "");
    const amount = Number(data.amount || 0);
    const currency = String(data.currency || "usd");
    const userId = String(context.auth.uid);

    // Validate inputs
    if (!dealId || dealId.length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "dealId is required"
      );
    }

    if (amount <= 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Amount must be greater than 0"
      );
    }

    // Get deal from Firestore
    const dealDoc = await admin.firestore()
      .collection("deals")
      .doc(dealId)
      .get();

    if (!dealDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Deal not found"
      );
    }

    const deal = dealDoc.data();

    // Verify deal availability
    if (!deal.isActive) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Deal is no longer active"
      );
    }

    if (deal.remainingQuantity <= 0) {
      throw new functions.https.HttpsError(
        "resource-exhausted",
        "Deal is sold out"
      );
    }

    if (Date.now() > deal.expirationTime) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Deal has expired"
      );
    }

    // Verify amount
    const expectedAmount = Math.round(Number(deal.dealPrice) * 100);
    const providedAmount = Math.round(amount * 100);

    if (Math.abs(expectedAmount - providedAmount) > 1) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `Amount mismatch. Expected ${deal.dealPrice}, got ${amount}`
      );
    }

    // Get user data
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    const userData = userDoc.exists ? userDoc.data() : {};

    // Create Payment Intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: expectedAmount,
      currency: currency.toLowerCase(),
      metadata: {
        userId: userId,
        dealId: dealId,
        dealTitle: String(deal.title || "Unknown"),
        businessName: String(deal.businessName || "Unknown"),
        userEmail: String(userData.email || "unknown"),
      },
      description: `Purchase: ${deal.title} at ${deal.businessName}`,
    });

    // Reserve inventory
    await admin.firestore()
      .collection("deals")
      .doc(dealId)
      .update({
        remainingQuantity: admin.firestore.FieldValue.increment(-1),
      });

    // Log transaction
    await admin.firestore()
      .collection("payment_intents")
      .doc(paymentIntent.id)
      .set({
        userId: userId,
        dealId: dealId,
        amount: deal.dealPrice,
        currency: currency,
        status: "pending",
        stripePaymentIntentId: paymentIntent.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log("Payment Intent created:", paymentIntent.id);

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (error: any) {
    console.error("Error creating payment intent:", error);

    if (error.code && error.message) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      "Failed to create payment intent: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Confirm Payment
 */
exports.confirmPayment = functions.https.onCall(async (data: any, context: any) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "User must be authenticated");
    }

    const paymentIntentId = String(data.paymentIntentId || "");
    const userId = String(context.auth.uid);

    if (!paymentIntentId || paymentIntentId.length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "paymentIntentId is required");
    }

    // Retrieve payment intent
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status !== "succeeded") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Payment not completed"
      );
    }

    // Get payment record
    const paymentIntentDoc = await admin.firestore()
      .collection("payment_intents")
      .doc(paymentIntentId)
      .get();

    if (!paymentIntentDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Payment record not found");
    }

    const paymentData = paymentIntentDoc.data();

    // Create purchase record
    const purchaseRef = await admin.firestore()
      .collection("purchases")
      .add({
        userId: userId,
        dealId: paymentData.dealId,
        amount: paymentData.amount,
        currency: paymentData.currency,
        stripePaymentIntentId: paymentIntentId,
        status: "completed",
        purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
        voucherCode: generateVoucherCode(),
        redeemed: false,
      });

    // Update payment intent status
    await admin.firestore()
      .collection("payment_intents")
      .doc(paymentIntentId)
      .update({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        purchaseId: purchaseRef.id,
      });

    // Add to user purchase history
    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("purchaseHistory")
      .doc(purchaseRef.id)
      .set({
        dealId: paymentData.dealId,
        purchaseDate: admin.firestore.FieldValue.serverTimestamp(),
        amount: paymentData.amount,
      });

    console.log("Purchase confirmed:", purchaseRef.id);

    return {
      success: true,
      purchaseId: purchaseRef.id,
      message: "Purchase completed successfully",
    };
  } catch (error: any) {
    console.error("Error confirming payment:", error);

    if (error.code && error.message) {
      throw error;
    }

    throw new functions.https.HttpsError(
      "internal",
      "Failed to confirm payment: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Webhook handler
 */
exports.stripeWebhook = functions.https.onRequest(async (req: any, res: any) => {
  const sig = req.headers["stripe-signature"];
  const config = functions.config();
  const webhookSecret = config.stripe && config.stripe.webhook_secret ?
    config.stripe.webhook_secret :
    "";

  if (!sig) {
    res.status(400).send("Missing stripe-signature header");
    return;
  }

  let event: any;

  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig,
      webhookSecret
    );
  } catch (err: any) {
    console.error("Webhook signature verification failed:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  // Handle events
  try {
    switch (event.type) {
    case "payment_intent.succeeded":
      await handlePaymentSuccess(event.data.object);
      break;

    case "payment_intent.payment_failed":
      await handlePaymentFailure(event.data.object);
      break;

    default:
      console.log(`Unhandled event type: ${event.type}`);
    }

    res.json({received: true});
  } catch (error: any) {
    console.error("Error handling webhook:", error);
    res.status(500).send(`Webhook handler failed: ${error.message}`);
  }
});

/**
 * Handle successful payment
 */
async function handlePaymentSuccess(paymentIntent: any): Promise<void> {
  console.log("Payment succeeded:", paymentIntent.id);

  try {
    await admin.firestore()
      .collection("payment_intents")
      .doc(paymentIntent.id)
      .update({
        status: "succeeded",
        succeededAt: admin.firestore.FieldValue.serverTimestamp(),
      });
  } catch (error: any) {
    console.error("Error updating payment status:", error);
  }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailure(paymentIntent: any): Promise<void> {
  console.log("Payment failed:", paymentIntent.id);

  try {
    const paymentIntentDoc = await admin.firestore()
      .collection("payment_intents")
      .doc(paymentIntent.id)
      .get();

    if (paymentIntentDoc.exists) {
      const data = paymentIntentDoc.data();

      // Restore inventory
      if (data && data.dealId) {
        await admin.firestore()
          .collection("deals")
          .doc(data.dealId)
          .update({
            remainingQuantity: admin.firestore.FieldValue.increment(1),
          });
      }

      // Update status
      await admin.firestore()
        .collection("payment_intents")
        .doc(paymentIntent.id)
        .update({
          status: "failed",
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          failureReason: paymentIntent.last_payment_error ?
            String(paymentIntent.last_payment_error.message) :
            "Unknown error",
        });
    }
  } catch (error: any) {
    console.error("Error handling payment failure:", error);
  }
}

/**
 * Generate voucher code
 */
function generateVoucherCode(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let code = "";
  for (let i = 0; i < 8; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}
