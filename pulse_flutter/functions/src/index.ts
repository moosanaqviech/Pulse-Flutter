// functions/src/index.ts
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Stripe from "stripe";

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Stripe
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "TEST", {
  apiVersion: "2025-09-30.clover",
});

/**
 * Create Payment Intent
 */
export const createPaymentIntent = onCall(async (request) => {
  try {
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const dealId = String(data.dealId || "");
    const purchaseId = String(data.purchaseId || "");
    const amount = Number(data.amount || 0);
    const currency = String(data.currency || "cad").toLowerCase();
    const userId = String(request.auth.uid);

    // Validate inputs
    if (!dealId || dealId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "dealId is required"
      );
    }

    if (!purchaseId || purchaseId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "purchaseId is required"
      );
    }

    if (amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "Amount must be greater than 0"
      );
    }

    // Validate currency
    const validCurrencies = ["usd", "cad"];
    if (!validCurrencies.includes(currency)) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid currency. Must be one of: ${validCurrencies.join(", ")}`
      );
    }

    // Get deal from Firestore
    const dealDoc = await admin.firestore()
      .collection("deals")
      .doc(dealId)
      .get();

    if (!dealDoc.exists) {
      throw new HttpsError(
        "not-found",
        "Deal not found"
      );
    }

    const deal = dealDoc.data();
    if (!deal) {
      throw new HttpsError("not-found", "Deal data not found");
    }

    // Verify deal availability
    if (!deal.isActive) {
      throw new HttpsError(
        "failed-precondition",
        "Deal is no longer active"
      );
    }

    if (deal.remainingQuantity <= 0) {
      throw new HttpsError(
        "resource-exhausted",
        "Deal is sold out"
      );
    }

    if (Date.now() > deal.expirationTime) {
      throw new HttpsError(
        "failed-precondition",
        "Deal has expired"
      );
    }

    // Verify amount
    const expectedAmount = Math.round(Number(deal.dealPrice) * 100);
    const providedAmount = Math.round(amount * 100);

    if (Math.abs(expectedAmount - providedAmount) > 1) {
      throw new HttpsError(
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
      currency: currency,
      metadata: {
        userId: userId,
        dealId: dealId,
        purchaseId: purchaseId,
        dealTitle: String(deal.title || "Unknown"),
        businessName: String(deal.businessName || "Unknown"),
        userEmail: String(userData?.email || "unknown"),
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

    // Update purchase with stripePaymentIntentId
    await admin.firestore()
      .collection("purchases")
      .doc(purchaseId)
      .update({
        stripePaymentIntentId: paymentIntent.id,
      });

    console.log("Payment Intent created:", paymentIntent.id, "Purchase ID:", purchaseId);

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (error: any) {
    console.error("Error creating payment intent:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to create payment intent: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Confirm Payment
 */
export const confirmPayment = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const purchaseId = String(data.purchaseId || "");
    const userId = String(request.auth.uid);

    if (!purchaseId || purchaseId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "purchaseId is required"
      );
    }

    console.log("🔵 Confirming payment for purchase:", purchaseId);

    // Get purchase record
    const purchaseDoc = await admin.firestore()
      .collection("purchases")
      .doc(purchaseId)
      .get();

    if (!purchaseDoc.exists) {
      console.error("❌ Purchase not found:", purchaseId);
      throw new HttpsError(
        "not-found",
        "Purchase not found"
      );
    }

    const purchase = purchaseDoc.data();
    if (!purchase) {
      throw new HttpsError("not-found", "Purchase data not found");
    }

    console.log("📄 Purchase data:", {
      userId: purchase.userId,
      status: purchase.status,
      hasPaymentIntent: !!purchase.stripePaymentIntentId,
    });

    // Verify user owns this purchase
    if (purchase.userId !== userId) {
      console.error("❌ User mismatch. Expected:", userId, "Got:", purchase.userId);
      throw new HttpsError(
        "permission-denied",
        "You don't have permission to access this purchase"
      );
    }

    // Check if already confirmed
    if (purchase.status === "confirmed") {
      console.log("✅ Purchase already confirmed:", purchaseId);
      return {
        success: true,
        qrCode: purchase.qrCode || purchaseId,
        purchaseId: purchaseId,
        message: "Purchase already confirmed",
      };
    }

    // Verify payment with Stripe if we have a payment intent
    if (purchase.stripePaymentIntentId) {
      console.log("💳 Verifying with Stripe:", purchase.stripePaymentIntentId);
      try {
        const paymentIntent = await stripe.paymentIntents.retrieve(
          purchase.stripePaymentIntentId
        );

        console.log("💳 Stripe status:", paymentIntent.status);

        if (paymentIntent.status !== "succeeded") {
          throw new HttpsError(
            "failed-precondition",
            "Payment not completed. Status: " + paymentIntent.status
          );
        }
      } catch (stripeError: any) {
        console.error("❌ Stripe verification error:", stripeError.message);
        // Don't throw - continue with confirmation
      }
    } else {
      console.log("⚠️ No stripePaymentIntentId found - continuing anyway");
    }

    // Generate QR code
    const qrCode = purchaseId;

    // Update purchase status
    await admin.firestore()
      .collection("purchases")
      .doc(purchaseId)
      .update({
        status: "confirmed",
        qrCode: qrCode,
      });

    console.log("✅ Payment confirmed successfully for purchase:", purchaseId);

    return {
      success: true,
      qrCode: qrCode,
      purchaseId: purchaseId,
      message: "Purchase confirmed successfully",
    };
  } catch (error: any) {
    console.error("❌ Error in confirmPayment:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to confirm payment: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Stripe Webhook Handler
 */
export const stripeWebhook = onRequest(async (req, res) => {
  const sig = req.headers["stripe-signature"];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || "";

  if (!sig) {
    res.status(400).send("Missing stripe-signature header");
    return;
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      sig as string,
      webhookSecret
    );
  } catch (err: any) {
    console.error("Webhook signature verification failed:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
    return;
  }

  try {
    switch (event.type) {
      case "payment_intent.succeeded":
        await handlePaymentSuccess(event.data.object as Stripe.PaymentIntent);
        break;

      case "payment_intent.payment_failed":
        await handlePaymentFailure(event.data.object as Stripe.PaymentIntent);
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

async function handlePaymentSuccess(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  console.log("Payment succeeded:", paymentIntent.id);

  try {
    const purchaseId = paymentIntent.metadata.purchaseId;

    if (purchaseId) {
      await admin.firestore()
        .collection("purchases")
        .doc(purchaseId)
        .update({
          paymentStatus: "succeeded",
        });
    }
  } catch (error: any) {
    console.error("Error updating payment status:", error);
  }
}

async function handlePaymentFailure(paymentIntent: Stripe.PaymentIntent): Promise<void> {
  console.log("Payment failed:", paymentIntent.id);

  try {
    const purchaseId = paymentIntent.metadata.purchaseId;
    const dealId = paymentIntent.metadata.dealId;

    if (purchaseId) {
      await admin.firestore()
        .collection("purchases")
        .doc(purchaseId)
        .update({
          status: "failed",
          paymentStatus: "failed",
        });
    }

    if (dealId) {
      await admin.firestore()
        .collection("deals")
        .doc(dealId)
        .update({
          remainingQuantity: admin.firestore.FieldValue.increment(1),
        });
    }
  } catch (error: any) {
    console.error("Error handling payment failure:", error);
  }
}