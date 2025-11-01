import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "TEST", {
  apiVersion: "2025-09-30.clover",
  typescript: true,
});

export const PLATFORM_FEE_PERCENTAGE = 0.12; // 12%