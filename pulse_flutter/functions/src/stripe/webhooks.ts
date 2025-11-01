import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import Stripe from "stripe";

import { stripe} from "../shared/stripe-client";
import { REGIONS, MEMORY, TIMEOUTS} from "../shared/constants";


export const stripeConnectWebhook = onRequest(
  {
    region: REGIONS.PRIMARY,
    memory: MEMORY.MEDIUM,
    timeoutSeconds: TIMEOUTS.SHORT,
  },
  async (request, response) => {
    const sig = request.headers["stripe-signature"];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET || "whsec";

    if (!sig) {
      response.status(400).send("Missing stripe-signature header");
      return;
    }

    let event: Stripe.Event;

    try {
      event = stripe.webhooks.constructEvent(
        request.rawBody,
        sig as string,
        webhookSecret
      );
    } catch (err: any) {
      console.error(`❌ Webhook error: ${err.message}`);
      response.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    console.log(`📥 Webhook: ${event.type}`);

    try {
      switch (event.type) {
        case "account.updated":
          await handleAccountUpdated(event.data.object as Stripe.Account);
          break;
        case "payment_intent.succeeded":
          await handlePaymentSucceeded(event.data.object as Stripe.PaymentIntent);
          break;
        case "payment_intent.payment_failed":
          await handlePaymentFailed(event.data.object as Stripe.PaymentIntent);
          break;
        default:
          console.log(`ℹ️ Unhandled: ${event.type}`);
      }

      response.json({ received: true });
    } catch (error: any) {
      console.error(`❌ Handler error: ${error.message}`);
      response.status(500).send(`Handler failed: ${error.message}`);
    }
  }
);

async function handleAccountUpdated(account: Stripe.Account) {
  const businessQuery = await admin
    .firestore()
    .collection("businesses")
    .where("stripeConnectedAccountId", "==", account.id)
    .limit(1)
    .get();

  if (!businessQuery.empty) {
    await businessQuery.docs[0].ref.update({
      stripeAccountOnboarded: account.charges_enabled && account.payouts_enabled,
      stripePayoutsEnabled: account.payouts_enabled,
      stripeAccountStatus: account.charges_enabled ? "active" : "pending",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

async function handlePaymentSucceeded(paymentIntent: Stripe.PaymentIntent) {
  console.log(`✅ Payment succeeded: ${paymentIntent.id}`);
}

async function handlePaymentFailed(paymentIntent: Stripe.PaymentIntent) {
  console.log(`❌ Payment failed: ${paymentIntent.id}`);
}