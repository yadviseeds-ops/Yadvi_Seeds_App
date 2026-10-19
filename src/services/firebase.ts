import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  getAuth,
  RecaptchaVerifier,
  signInWithPhoneNumber,
  signOut,
  ConfirmationResult,
  User
} from 'firebase/auth';

// Standard Firebase Web configuration for project 'yadvi-seed-app-5f306'
const firebaseConfig = {
  apiKey: "AIzaSyCiheQSrduTZMTGRTLDHkblR62cc3ffasI",
  authDomain: "yadvi-seed-app-5f306.firebaseapp.com",
  projectId: "yadvi-seed-app-5f306",
  storageBucket: "yadvi-seed-app-5f306.firebasestorage.app",
  messagingSenderId: "943376646148",
  appId: "1:943376646148:web:ca0ddc183c623b5457b551",
};

// Initialize or reuse Firebase App instance
const app = getApps().length > 0 ? getApp() : initializeApp(firebaseConfig);
export const auth = getAuth(app);

// Keep track of active reCAPTCHA verifier instance and in-flight request lock
let activeRecaptchaVerifier: RecaptchaVerifier | null = null;
let isOtpInProgress: boolean = false;

/**
 * Cleanly clears and destroys the active RecaptchaVerifier and empties its DOM container.
 */
export function cleanupRecaptchaVerifier(containerId: string = 'recaptcha-container'): void {
  if (isOtpInProgress) {
    return;
  }
  if (activeRecaptchaVerifier) {
    try {
      activeRecaptchaVerifier.clear();
    } catch (_) {
      // Ignore cleanup error if already cleared
    }
    activeRecaptchaVerifier = null;
  }
  if (typeof document !== 'undefined') {
    const el = document.getElementById(containerId);
    if (el) {
      el.innerHTML = '';
    }
  }
}

/**
 * Initializes or resets an invisible RecaptchaVerifier on the specified container DOM element.
 */
export function setupRecaptchaVerifier(containerId: string = 'recaptcha-container'): RecaptchaVerifier {
  // If an OTP request is actively in-flight, return the existing verifier to prevent race conditions
  if (isOtpInProgress && activeRecaptchaVerifier) {
    return activeRecaptchaVerifier;
  }

  // Clean up any stale verifier and DOM elements
  cleanupRecaptchaVerifier(containerId);

  activeRecaptchaVerifier = new RecaptchaVerifier(auth, containerId, {
    size: 'invisible',
    callback: () => {
      // reCAPTCHA solved
    },
    'expired-callback': () => {
      // Response expired - clean up so next attempt initializes freshly
      cleanupRecaptchaVerifier(containerId);
    }
  });

  return activeRecaptchaVerifier;
}

/**
 * Sends a phone verification OTP using Firebase Web Phone Auth.
 * Accepts mobile number and formats it as +91XXXXXXXXXX.
 * Explicitly awaits verifier.render() before invoking signInWithPhoneNumber.
 */
export async function sendFirebasePhoneOtp(
  mobile: string,
  verifier: RecaptchaVerifier
): Promise<ConfirmationResult> {
  if (isOtpInProgress) {
    throw new Error('An OTP request is already in progress. Please wait.');
  }

  const cleanMobile = mobile.replace(/\D/g, '');
  const digits10 = cleanMobile.length === 12 && cleanMobile.startsWith('91')
    ? cleanMobile.slice(2)
    : cleanMobile.length === 11 && cleanMobile.startsWith('0')
      ? cleanMobile.slice(1)
      : cleanMobile;

  if (digits10.length !== 10) {
    throw new Error('Please enter a valid 10-digit mobile number.');
  }

  isOtpInProgress = true;
  try {
    // Explicitly await rendering to ensure Google reCAPTCHA scripts and widget ID are established
    await verifier.render();

    const formattedPhone = `+91${digits10}`;
    const confirmation = await signInWithPhoneNumber(auth, formattedPhone, verifier);
    return confirmation;
  } catch (err: any) {
    // Clean up verifier on error so subsequent attempts do not encounter detached widget states
    cleanupRecaptchaVerifier();
    throw err;
  } finally {
    isOtpInProgress = false;
  }
}

/**
 * Confirms the OTP entered by the user and retrieves the Firebase ID Token (JWT).
 */
export async function confirmFirebasePhoneOtp(
  confirmationResult: ConfirmationResult,
  otpCode: string
): Promise<{ user: User; idToken: string }> {
  const userCredential = await confirmationResult.confirm(otpCode.trim());
  const user = userCredential.user;
  const idToken = await user.getIdToken();

  return { user, idToken };
}

/**
 * Signs out of the Firebase client session.
 */
export async function logoutFirebase(): Promise<void> {
  try {
    await signOut(auth);
  } catch (err) {
    console.error('Error signing out of Firebase:', err);
  }
}
