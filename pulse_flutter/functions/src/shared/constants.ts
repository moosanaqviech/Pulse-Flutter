export const REGIONS = {
  PRIMARY: "us-central1",
} as const;

export const MEMORY = {
  SMALL: "256MiB",
  MEDIUM: "512MiB",
  LARGE: "1GiB",
} as const;

export const TIMEOUTS = {
  SHORT: 60,
  MEDIUM: 120,
  LONG: 540,
} as const;

export const RATE_LIMITS = {
  STRIPE_ACCOUNT_CREATE: { maxAttempts: 3, windowMinutes: 60 },
  PAYMENT_CREATE: { maxAttempts: 10, windowMinutes: 60 },
  ACCOUNT_LINK: { maxAttempts: 5, windowMinutes: 60 },
} as const;