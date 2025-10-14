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

// Add these functions to functions/src/index.ts

/**
 * Verify Voucher (check validity without redeeming)
 */
/**
 * Verify Voucher (check validity without redeeming)
 */
/**
 * Verify Voucher (check validity without redeeming) - Updated to include stripePaymentIntentId
 */
export const verifyVoucher = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const purchaseId = String(data.purchaseId || "");

    if (!purchaseId || purchaseId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "purchaseId is required"
      );
    }

    console.log("🔍 Verifying voucher:", purchaseId);

    // Get purchase record
    const purchaseDoc = await admin.firestore()
      .collection("purchases")
      .doc(purchaseId)
      .get();

    if (!purchaseDoc.exists) {
      console.error("❌ Purchase not found:", purchaseId);
      throw new HttpsError(
        "not-found",
        "Voucher not found"
      );
    }

    const purchase = purchaseDoc.data();
    if (!purchase) {
      throw new HttpsError("not-found", "Purchase data not found");
    }

    console.log("📄 Purchase verification:", {
      status: purchase.status,
      isExpired: Date.now() > purchase.expirationTime,
      isRedeemed: purchase.status === "redeemed",
    });

    // Check if purchase is confirmed (has QR code)
    if (purchase.status !== "confirmed") {
      throw new HttpsError(
        "failed-precondition",
        "Voucher is not valid for redemption"
      );
    }

    // Check if already redeemed
    if (purchase.status === "redeemed") {
      throw new HttpsError(
        "already-exists",
        "Voucher has already been redeemed"
      );
    }

    // Check if expired
    if (Date.now() > purchase.expirationTime) {
      throw new HttpsError(
        "failed-precondition",
        "Voucher has expired"
      );
    }

    console.log("✅ Voucher verification successful:", purchaseId);

    // Return data that works with both Consumer and Business models
    const purchaseData = {
      id: String(purchaseDoc.id),
      userId: String(purchase.userId || ""),
      dealId: String(purchase.dealId || ""),
      dealTitle: String(purchase.dealTitle || ""),
      businessName: String(purchase.businessName || ""),
      amount: Number(purchase.amount || 0),
      status: String(purchase.status || ""),
      purchaseTime: purchase.purchaseTime ? Number(purchase.purchaseTime) : Date.now(),
      expirationTime: purchase.expirationTime ? Number(purchase.expirationTime) : Date.now(),
      imageUrl: String(purchase.imageUrl || ""),
      qrCode: String(purchase.qrCode || ""),
      stripePaymentIntentId: String(purchase.stripePaymentIntentId || ""), // Added this field
      dealSnapshot: purchase.dealSnapshot || null, // Include dealSnapshot
      redeemedAt: purchase.redeemedAt || null,
      redeemedBy: String(purchase.redeemedBy || ""),
    };

    return {
      success: true,
      purchase: purchaseData,
      message: "Voucher is valid for redemption",
    };
  } catch (error: any) {
    console.error("❌ Error in verifyVoucher:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to verify voucher: " + String(error.message || "Unknown error")
    );
  }
});
/**
 * Redeem Voucher (mark as redeemed)
 */
export const redeemVoucher = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const purchaseId = String(data.purchaseId || "");

    if (!purchaseId || purchaseId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "purchaseId is required"
      );
    }

    console.log("🎯 Redeeming voucher:", purchaseId);

    // Get purchase record with transaction
    const purchaseRef = admin.firestore()
      .collection("purchases")
      .doc(purchaseId);

    const result = await admin.firestore().runTransaction(async (transaction) => {
      const purchaseDoc = await transaction.get(purchaseRef);

      if (!purchaseDoc.exists) {
        throw new HttpsError(
          "not-found",
          "Voucher not found"
        );
      }

      const purchase = purchaseDoc.data();
      if (!purchase) {
        throw new HttpsError("not-found", "Purchase data not found");
      }

      // Check if purchase is confirmed (has QR code)
      if (purchase.status !== "confirmed") {
        throw new HttpsError(
          "failed-precondition",
          "Voucher is not valid for redemption"
        );
      }

      // Check if already redeemed
      if (purchase.status === "redeemed") {
        throw new HttpsError(
          "already-exists",
          "Voucher has already been redeemed"
        );
      }

      // Check if expired
      if (Date.now() > purchase.expirationTime) {
        throw new HttpsError(
          "failed-precondition",
          "Voucher has expired"
        );
      }

      // Update purchase status to redeemed
      transaction.update(purchaseRef, {
        status: "redeemed",
        redeemedAt: admin.firestore.FieldValue.serverTimestamp(),
        redeemedBy: request.auth!.uid,
      });

      return {
        id: purchaseDoc.id,
        userId: purchase.userId,
        dealId: purchase.dealId,
        dealTitle: purchase.dealTitle,
        businessName: purchase.businessName,
        amount: purchase.amount,
        status: "redeemed",
        purchaseTime: purchase.purchaseTime,
        expirationTime: purchase.expirationTime,
        imageUrl: purchase.imageUrl || "",
        qrCode: purchase.qrCode,
        redeemedAt: Date.now(),
      };
    });

    console.log("✅ Voucher redeemed successfully:", purchaseId);

    return {
      success: true,
      purchase: result,
      message: "Voucher redeemed successfully",
    };
  } catch (error: any) {
    console.error("❌ Error in redeemVoucher:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to redeem voucher: " + String(error.message || "Unknown error")
    );
  }
});

// Add these functions to your existing functions/src/index.ts file

/**
 * Create Payment Intent with Setup Future Usage (Enhanced version)
 */
// Add these functions to your existing functions/src/index.ts file

/**
 * Create Payment Intent with Setup Future Usage (Enhanced version)
 */
export const createPaymentIntentWithSetup = onCall(async (request) => {
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
    const setupFutureUsage = Boolean(data.setupFutureUsage || false);
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

    // Get user data - but don't require it to exist for consumers
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    const userData = userDoc.exists ? userDoc.data() : null;
    
    // For consumers, use auth email if available
    const userEmail = userData?.email || request.auth.token.email || "unknown";

    // Create or get Stripe customer if setup for future usage
    let customerId: string | undefined;
    if (setupFutureUsage) {
      if (userData?.stripeCustomerId) {
        customerId = userData.stripeCustomerId;
      } else {
        // Create new Stripe customer
        const customer = await stripe.customers.create({
          email: userEmail,
          metadata: {
            userId: userId,
            userType: userData ? "business" : "consumer",
          },
        });
        
        customerId = customer.id;
        
        // Save customer ID to user record - create if doesn't exist
        try {
          if (userData) {
            // Update existing business user
            await admin.firestore()
              .collection("users")
              .doc(userId)
              .update({
                stripeCustomerId: customerId,
              });
          } else {
            // Create new consumer user record
            await admin.firestore()
              .collection("users")
              .doc(userId)
              .set({
                email: userEmail,
                stripeCustomerId: customerId,
                userType: "consumer",
                createdAt: admin.firestore.Timestamp.now(),
              });
          }
        } catch (error: any) {
          console.warn("Could not save customer ID to user record:", error.message);
          // Continue anyway - the customer exists in Stripe
        }
      }
    }

    // Create Payment Intent parameters
    const paymentIntentParams: any = {
      amount: expectedAmount,
      currency: currency,
      metadata: {
        userId: userId,
        dealId: dealId,
        purchaseId: purchaseId,
        dealTitle: String(deal.title || "Unknown"),
        businessName: String(deal.businessName || "Unknown"),
        userEmail: userEmail,
      },
      description: `Purchase: ${deal.title} at ${deal.businessName}`,
    };

    // Add customer and setup future usage if requested
    if (setupFutureUsage && customerId) {
      paymentIntentParams.customer = customerId;
      paymentIntentParams.setup_future_usage = "off_session";
    }

    // Create Payment Intent
    const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);

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

    console.log("Payment Intent created with setup:", paymentIntent.id, "Purchase ID:", purchaseId);

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
    };
  } catch (error: any) {
    console.error("Error creating payment intent with setup:", error);

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
 * Create Payment Intent with Saved Payment Method
 */
export const createPaymentIntentWithSavedMethod = onCall(async (request) => {
  try {
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
    const paymentMethodId = String(data.paymentMethodId || "");
    const userId = String(request.auth.uid);

    // Validation
    if (!paymentMethodId || paymentMethodId.length === 0) {
      throw new HttpsError("invalid-argument", "paymentMethodId is required");
    }

    // Validate currency
    const validCurrencies = ["usd", "cad"];
    if (!validCurrencies.includes(currency)) {
      throw new HttpsError(
        "invalid-argument",
        `Invalid currency. Must be one of: ${validCurrencies.join(", ")}`
      );
    }

    // Get user's Stripe customer ID - check if user exists first
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "User not found - please save a payment method first");
    }

    const userData = userDoc.data()!;
    if (!userData?.stripeCustomerId) {
      throw new HttpsError("failed-precondition", "User has no Stripe customer ID");
    }

    // Get deal from Firestore
    const dealDoc = await admin.firestore()
      .collection("deals")
      .doc(dealId)
      .get();

    if (!dealDoc.exists) {
      throw new HttpsError("not-found", "Deal not found");
    }

    const deal = dealDoc.data()!;

    // Verify deal availability
    if (!deal.isActive) {
      throw new HttpsError("failed-precondition", "Deal is no longer active");
    }

    if (deal.remainingQuantity <= 0) {
      throw new HttpsError("resource-exhausted", "Deal is sold out");
    }

    if (Date.now() > deal.expirationTime) {
      throw new HttpsError("failed-precondition", "Deal has expired");
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

    // Verify payment method belongs to customer
    const paymentMethod = await stripe.paymentMethods.retrieve(paymentMethodId);
    if (paymentMethod.customer !== userData.stripeCustomerId) {
      throw new HttpsError("permission-denied", "Payment method does not belong to user");
    }

    // For consumers, use auth email if available
    const userEmail = userData?.email || request.auth.token.email || "unknown";

    // Create Payment Intent with saved payment method
    const paymentIntent = await stripe.paymentIntents.create({
      amount: expectedAmount,
      currency: currency,
      customer: userData.stripeCustomerId,
      payment_method: paymentMethodId,
      confirmation_method: "manual",
      confirm: true,
      return_url: "https://your-app.com/return", // You can customize this
      metadata: {
        userId: userId,
        dealId: dealId,
        purchaseId: purchaseId,
        dealTitle: String(deal.title || "Unknown"),
        businessName: String(deal.businessName || "Unknown"),
        userEmail: userEmail,
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

    console.log("Payment Intent with saved method created:", paymentIntent.id);

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id,
      status: paymentIntent.status,
    };
  } catch (error: any) {
    console.error("Error creating payment intent with saved method:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    // Handle Stripe-specific errors
    if (error.type === "StripeCardError") {
      throw new HttpsError("invalid-argument", error.message);
    }

    throw new HttpsError(
      "internal",
      "Failed to create payment intent: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Save Payment Method After Payment
 */
export const savePaymentMethodAfterPayment = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const userId = String(request.auth.uid);
    const clientSecret = String(data.clientSecret || "");

    if (!clientSecret) {
      throw new HttpsError("invalid-argument", "clientSecret is required");
    }

    // Extract payment intent ID from client secret
    const paymentIntentId = clientSecret.split("_secret_")[0];

    // Retrieve payment intent from Stripe
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (!paymentIntent.payment_method) {
      throw new HttpsError("failed-precondition", "No payment method attached to payment intent");
    }

    // Get payment method details
    const paymentMethod = await stripe.paymentMethods.retrieve(
      paymentIntent.payment_method as string
    );

    if (paymentMethod.type !== "card" || !paymentMethod.card) {
      throw new HttpsError("invalid-argument", "Only card payment methods can be saved");
    }

    // Get user's Stripe customer ID
    const userDoc = await admin.firestore()
      .collection("users")
      .doc(userId)
      .get();

    const userData = userDoc.data();
    if (!userData?.stripeCustomerId) {
      throw new HttpsError("failed-precondition", "User has no Stripe customer ID");
    }

    // Attach payment method to customer (if not already attached)
    if (paymentMethod.customer !== userData.stripeCustomerId) {
      await stripe.paymentMethods.attach(paymentMethod.id, {
        customer: userData.stripeCustomerId,
      });
    }

    // Check if this card is already saved
    const existingMethodQuery = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("payment_methods")
      .where("cardLast4", "==", paymentMethod.card.last4)
      .where("cardBrand", "==", paymentMethod.card.brand)
      .where("isActive", "==", true)
      .get();

    if (!existingMethodQuery.empty) {
      console.log("Payment method already exists for user");
      return { success: true, message: "Payment method already saved" };
    }

    // Check if this is the user's first saved card
    const existingMethodsQuery = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("payment_methods")
      .where("isActive", "==", true)
      .get();

    const isFirstCard = existingMethodsQuery.empty;

    // Save payment method to Firestore
    const paymentMethodDoc = {
      userId: userId,
      stripePaymentMethodId: paymentMethod.id,
      cardLast4: paymentMethod.card.last4,
      cardBrand: paymentMethod.card.brand,
      cardExpMonth: paymentMethod.card.exp_month.toString().padStart(2, "0"),
      cardExpYear: paymentMethod.card.exp_year.toString(),
      cardholderName: paymentMethod.billing_details.name || null,
      isDefault: isFirstCard, // First card becomes default
      isActive: true,
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    };

    await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("payment_methods")
      .add(paymentMethodDoc);

    console.log("Payment method saved successfully for user:", userId);

    return {
      success: true,
      message: "Payment method saved successfully",
    };
  } catch (error: any) {
    console.error("Error saving payment method:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to save payment method: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Delete Saved Payment Method
 */
export const deleteSavedPaymentMethod = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const userId = String(request.auth.uid);
    const paymentMethodId = String(data.paymentMethodId || "");

    if (!paymentMethodId) {
      throw new HttpsError("invalid-argument", "paymentMethodId is required");
    }

    // Find the payment method in Firestore
    const paymentMethodQuery = await admin.firestore()
      .collection("users")
      .doc(userId)
      .collection("payment_methods")
      .where("stripePaymentMethodId", "==", paymentMethodId)
      .where("isActive", "==", true)
      .get();

    if (paymentMethodQuery.empty) {
      throw new HttpsError("not-found", "Payment method not found");
    }

    const paymentMethodDoc = paymentMethodQuery.docs[0];
    const paymentMethodData = paymentMethodDoc.data();

    // Detach payment method from Stripe customer
    try {
      await stripe.paymentMethods.detach(paymentMethodId);
    } catch (stripeError: any) {
      console.warn("Error detaching payment method from Stripe:", stripeError.message);
      // Continue with Firestore deletion even if Stripe fails
    }

    // Mark as inactive in Firestore
    await paymentMethodDoc.ref.update({
      isActive: false,
      updatedAt: admin.firestore.Timestamp.now(),
    });

    // If this was the default payment method, make another one default
    if (paymentMethodData.isDefault) {
      const otherMethodsQuery = await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("payment_methods")
        .where("isActive", "==", true)
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();

      if (!otherMethodsQuery.empty) {
        await otherMethodsQuery.docs[0].ref.update({
          isDefault: true,
          updatedAt: admin.firestore.Timestamp.now(),
        });
      }
    }

    console.log("Payment method deleted successfully:", paymentMethodId);

    return {
      success: true,
      message: "Payment method deleted successfully",
    };
  } catch (error: any) {
    console.error("Error deleting payment method:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to delete payment method: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Confirm Payment Intent (for automatic payments)
 */
export const confirmPaymentIntent = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const clientSecret = String(data.clientSecret || "");

    if (!clientSecret) {
      throw new HttpsError("invalid-argument", "clientSecret is required");
    }

    // Extract payment intent ID from client secret
    const paymentIntentId = clientSecret.split("_secret_")[0];

    // Retrieve and confirm payment intent
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    if (paymentIntent.status === "succeeded") {
      return { success: true, status: "succeeded" };
    }

    if (paymentIntent.status === "requires_confirmation") {
      const confirmedPaymentIntent = await stripe.paymentIntents.confirm(paymentIntentId);
      return { success: true, status: confirmedPaymentIntent.status };
    }

    return { success: false, status: paymentIntent.status };

  } catch (error: any) {
    console.error("Error confirming payment intent:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to confirm payment intent: " + String(error.message || "Unknown error")
    );
  }
});

/**
 * Set Default Payment Method
 */
export const setDefaultPaymentMethod = onCall(async (request) => {
  try {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const data = request.data;
    const userId = String(request.auth.uid);
    const paymentMethodId = String(data.paymentMethodId || "");

    if (!paymentMethodId) {
      throw new HttpsError("invalid-argument", "paymentMethodId is required");
    }

    // Use transaction to ensure consistency
    await admin.firestore().runTransaction(async (transaction) => {
      // Find the payment method to set as default
      const targetMethodQuery = await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("payment_methods")
        .where("stripePaymentMethodId", "==", paymentMethodId)
        .where("isActive", "==", true)
        .get();

      if (targetMethodQuery.empty) {
        throw new HttpsError("not-found", "Payment method not found");
      }

      // Clear current default
      const currentDefaultQuery = await admin.firestore()
        .collection("users")
        .doc(userId)
        .collection("payment_methods")
        .where("isDefault", "==", true)
        .where("isActive", "==", true)
        .get();

      // Update current default to false
      currentDefaultQuery.docs.forEach((doc) => {
        transaction.update(doc.ref, {
          isDefault: false,
          updatedAt: admin.firestore.Timestamp.now(),
        });
      });

      // Set new default
      const targetMethodDoc = targetMethodQuery.docs[0];
      transaction.update(targetMethodDoc.ref, {
        isDefault: true,
        updatedAt: admin.firestore.Timestamp.now(),
      });
    });

    console.log("Default payment method updated:", paymentMethodId);

    return {
      success: true,
      message: "Default payment method updated successfully",
    };
  } catch (error: any) {
    console.error("Error setting default payment method:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      "Failed to set default payment method: " + String(error.message || "Unknown error")
    );
  }
});