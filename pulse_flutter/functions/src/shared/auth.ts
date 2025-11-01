// ============================================
// functions/src/shared/auth.ts (Functions V2 + Clover)
// ============================================

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/**
 * Verify user owns the business
 * Throws HttpsError if validation fails
 */
export async function verifyBusinessOwnership(
  businessId: string,
  userId: string
): Promise<void> {
  const businessDoc = await admin
    .firestore()
    .collection("businesses")
    .doc(businessId)
    .get();

  if (!businessDoc.exists) {
    throw new HttpsError("not-found", "Business not found");
  }

  const business = businessDoc.data();
  if (!business || business.ownerId !== userId) {
    throw new HttpsError(
      "permission-denied",
      "You don't have permission to access this business"
    );
  }
}

/**
 * Rate limiting helper
 * Returns true if action is allowed, false if rate limit exceeded
 */
export async function checkRateLimit(
  userId: string,
  action: string,
  maxAttempts: number,
  windowMinutes: number
): Promise<boolean> {
  const now = Date.now();
  const windowStart = now - windowMinutes * 60 * 1000;

  const rateLimitRef = admin
    .firestore()
    .collection("rate_limits")
    .doc(`${userId}_${action}`);

  const doc = await rateLimitRef.get();
  const data = doc.data();

  if (!data) {
    // First attempt
    await rateLimitRef.set({
      attempts: 1,
      firstAttempt: now,
      lastAttempt: now,
    });
    return true;
  }

  // Check if outside window
  if (data.firstAttempt < windowStart) {
    // Reset counter
    await rateLimitRef.set({
      attempts: 1,
      firstAttempt: now,
      lastAttempt: now,
    });
    return true;
  }

  // Check if exceeded limit
  if (data.attempts >= maxAttempts) {
    return false;
  }

  // Increment counter
  await rateLimitRef.update({
    attempts: admin.firestore.FieldValue.increment(1),
    lastAttempt: now,
  });

  return true;
}

/**
 * Verify user is authenticated
 * Throws HttpsError if not authenticated
 */
export function requireAuth(auth: any): string {
  if (!auth || !auth.uid) {
    throw new HttpsError("unauthenticated", "Must be authenticated");
  }
  return auth.uid;
}

/**
 * Verify email matches business owner's email
 */
export async function verifyBusinessEmail(
  businessId: string,
  email: string
): Promise<void> {
  const businessDoc = await admin
    .firestore()
    .collection("businesses")
    .doc(businessId)
    .get();

  if (!businessDoc.exists) {
    throw new HttpsError("not-found", "Business not found");
  }

  const business = businessDoc.data();
  if (business?.email !== email) {
    throw new HttpsError(
      "invalid-argument",
      "Email must match business email"
    );
  }
}

/**
 * Verify business name matches registered name
 */
export async function verifyBusinessName(
  businessId: string,
  name: string
): Promise<void> {
  const businessDoc = await admin
    .firestore()
    .collection("businesses")
    .doc(businessId)
    .get();

  if (!businessDoc.exists) {
    throw new HttpsError("not-found", "Business not found");
  }

  const business = businessDoc.data();
  if (business?.name !== name) {
    throw new HttpsError(
      "invalid-argument",
      "Business name must match registered name"
    );
  }
}

/**
 * Get business data with validation
 * Returns business data or throws error
 */
export async function getBusiness(businessId: string): Promise<any> {
  const businessDoc = await admin
    .firestore()
    .collection("businesses")
    .doc(businessId)
    .get();

  if (!businessDoc.exists) {
    throw new HttpsError("not-found", "Business not found");
  }

  return businessDoc.data();
}