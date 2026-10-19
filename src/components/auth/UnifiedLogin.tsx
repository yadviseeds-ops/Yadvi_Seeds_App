import React, { useState, useEffect } from 'react';
import { useAppState } from '../../context/AppStateContext';
import { api } from '../../services/api';
import {
  setupRecaptchaVerifier,
  cleanupRecaptchaVerifier,
  sendFirebasePhoneOtp,
  confirmFirebasePhoneOtp
} from '../../services/firebase';
import type { ConfirmationResult } from 'firebase/auth';
import { AlertCircle, CheckCircle, ShieldCheck, KeyRound, Phone, Lock, ArrowRight, RefreshCw } from 'lucide-react';

export const UnifiedLogin: React.FC = () => {
  const { handleRequestOtp, handleVerifyOtp, handleLoginPassword, handleLoginFirebase } = useAppState();

  const [role, setRole] = useState<'Administrator' | 'Field Executive' | 'Shop Owner'>('Administrator');
  const [authMode, setAuthMode] = useState<'otp' | 'password'>('otp');
  const [username, setUsername] = useState('ADMIN');
  const [password, setPassword] = useState('');
  const [mobile, setMobile] = useState('9876543210');
  const [otp, setOtp] = useState('');

  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [otpRequested, setOtpRequested] = useState(false);
  const [successMsg, setSuccessMsg] = useState<string | null>(null);
  const [confirmationResult, setConfirmationResult] = useState<ConfirmationResult | null>(null);

  // Clean up reCAPTCHA verifier on component unmount
  useEffect(() => {
    return () => {
      cleanupRecaptchaVerifier('recaptcha-container');
    };
  }, []);

  // Clear reCAPTCHA and OTP states when role or authMode switches
  const handleSelectRole = (selectedRole: 'Administrator' | 'Field Executive' | 'Shop Owner') => {
    cleanupRecaptchaVerifier('recaptcha-container');
    setRole(selectedRole);
    setIsDropdownOpen(false);
    setError(null);
    setSuccessMsg(null);
    setOtpRequested(false);
    setConfirmationResult(null);
    setOtp('');
    setPassword('');

    if (selectedRole === 'Administrator') {
      setUsername('ADMIN');
      setMobile('9876543210');
      setAuthMode('otp'); // Primary Administrator mode is Firebase OTP
    } else if (selectedRole === 'Field Executive') {
      setUsername('FE001');
      setMobile('9848011223');
      setAuthMode('otp');
    } else if (selectedRole === 'Shop Owner') {
      setUsername('SHOP001');
      setMobile('9848023456');
      setAuthMode('otp');
    }
  };

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (loading) return;
    setError(null);
    setSuccessMsg(null);
    setLoading(true);

    try {
      await handleLoginPassword(username.trim(), password);
    } catch (err: any) {
      setError(err.message || 'Invalid username or password.');
    } finally {
      setLoading(false);
    }
  };

  const handleSendOtp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (loading) return;
    setError(null);
    setSuccessMsg(null);

    const cleanUser = username.trim();
    const cleanMobile = mobile.replace(/\D/g, '');

    if (!cleanUser) {
      setError('Please enter your username.');
      return;
    }

    if (cleanMobile.length < 10) {
      setError('Please enter a valid 10-digit mobile number.');
      return;
    }

    setLoading(true);

    try {
      if (role === 'Administrator') {
        // Step 1: Pre-flight verify that user exists & is active in the backend
        await api.verifyUser(cleanUser, cleanMobile);

        // Step 2: Set up reCAPTCHA verifier container
        const verifier = setupRecaptchaVerifier('recaptcha-container');

        // Step 3: Trigger Firebase Phone Authentication
        const confirmation = await sendFirebasePhoneOtp(cleanMobile, verifier);
        setConfirmationResult(confirmation);
        setOtpRequested(true);
        setSuccessMsg(`OTP dispatched to +91 ${cleanMobile.slice(-10)} via Firebase.`);
      } else {
        // SO & FE backend-managed flow in web mock
        await handleRequestOtp(cleanUser, cleanMobile);
        setOtpRequested(true);
        setSuccessMsg('OTP sent successfully.');
      }
    } catch (err: any) {
      console.error('OTP Request Error:', err);
      let message = err.message || 'Failed to request OTP. Please verify your details.';
      if (err.code === 'auth/invalid-phone-number') {
        message = 'Invalid phone number format. Please enter a valid 10-digit mobile number.';
      } else if (err.code === 'auth/too-many-requests') {
        message = 'Too many requests. Please wait a few moments before trying again.';
      } else if (err.code === 'auth/quota-exceeded') {
        message = 'SMS quota reached. Please try test credentials or contact support.';
      } else if (err.code === 'auth/invalid-app-credential') {
        if (typeof window !== 'undefined' && window.location.hostname === '127.0.0.1') {
          message = 'App verification rejected. Please access via http://localhost:5173 (authorized domain in Firebase).';
        } else {
          message = 'App verification failed (invalid-app-credential). Ensure you access via http://localhost:5173 and disable ad-blockers/privacy shields.';
        }
      }
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (loading) return;
    setError(null);

    const cleanUser = username.trim();
    const cleanMobile = mobile.replace(/\D/g, '');

    if (otp.length < 6) {
      setError('Please enter the complete 6-digit OTP.');
      return;
    }

    setLoading(true);

    try {
      if (role === 'Administrator') {
        if (!confirmationResult) {
          throw new Error('No active OTP session found. Please request a new OTP.');
        }

        // Step 4: Confirm Firebase OTP and obtain Firebase ID token
        const { idToken } = await confirmFirebasePhoneOtp(confirmationResult, otp);

        // Step 5: Send Firebase ID token to backend /api/v1/auth/login-firebase
        await handleLoginFirebase(cleanUser, cleanMobile, idToken);
      } else {
        await handleVerifyOtp(cleanUser, cleanMobile, otp);
      }
    } catch (err: any) {
      console.error('OTP Verification Error:', err);
      let message = err.message || 'Verification failed. Incorrect OTP.';
      if (err.code === 'auth/invalid-verification-code') {
        message = 'Invalid OTP. Please check the code and try again.';
      } else if (err.code === 'auth/code-expired') {
        message = 'The OTP code has expired. Please request a new one.';
      }
      setError(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full bg-[#f2f6f3] flex flex-col justify-center items-center p-4 font-sans select-none relative">
      {/* Invisible reCAPTCHA container for Firebase Phone Auth */}
      <div id="recaptcha-container"></div>

      <div className="w-full max-w-md bg-white rounded-2xl shadow-xl p-8 border border-slate-100 relative z-10">

        {/* Header */}
        <div className="text-center mb-6">
          <div className="mx-auto w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center mb-4">
            <ShieldCheck className="w-7 h-7 text-emerald-600" />
          </div>
          <h1 className="text-2xl font-bold text-slate-800">Secure Login</h1>
          <p className="text-slate-500 text-sm mt-1">
            {role === 'Administrator'
              ? authMode === 'password'
                ? 'Sign in using Administrator Password'
                : 'Sign in using Firebase Phone OTP'
              : 'Authenticate via SMS OTP to continue'}
          </p>
        </div>

        {/* Status Messages */}
        {error && (
          <div className="mb-6 p-4 bg-red-50 text-red-700 rounded-xl flex items-start gap-3 border border-red-100 animate-in fade-in slide-in-from-top-2">
            <AlertCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />
            <span className="text-sm font-medium">{error}</span>
          </div>
        )}
        {successMsg && (
          <div className="mb-6 p-4 bg-emerald-50 text-emerald-700 rounded-xl flex items-start gap-3 border border-emerald-100 animate-in fade-in slide-in-from-top-2">
            <CheckCircle className="w-5 h-5 flex-shrink-0 mt-0.5" />
            <span className="text-sm font-medium">{successMsg}</span>
          </div>
        )}

        {/* Admin Authentication Mode Tabs */}
        {role === 'Administrator' && !otpRequested && (
          <div className="flex bg-slate-100 p-1 rounded-xl mb-6">
            <button
              type="button"
              onClick={() => {
                setAuthMode('otp');
                setError(null);
                setSuccessMsg(null);
              }}
              className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 ${
                authMode === 'otp'
                  ? 'bg-white text-emerald-800 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <Phone className="w-3.5 h-3.5" />
              <span>Firebase OTP</span>
            </button>
            <button
              type="button"
              onClick={() => {
                setAuthMode('password');
                setError(null);
                setSuccessMsg(null);
              }}
              className={`flex-1 py-2 text-xs font-bold rounded-lg transition-all flex items-center justify-center gap-1.5 ${
                authMode === 'password'
                  ? 'bg-white text-emerald-800 shadow-sm'
                  : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <Lock className="w-3.5 h-3.5" />
              <span>Password Fallback</span>
            </button>
          </div>
        )}

        {/* Form: Password Login for Admin */}
        {role === 'Administrator' && authMode === 'password' ? (
          <form onSubmit={handlePasswordLogin} className="space-y-5">
            {/* Role Selection */}
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Select Role</label>
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                  className="w-full bg-slate-50 border border-slate-200 text-left px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all text-slate-800 font-medium flex items-center justify-between"
                >
                  {role}
                  <div className="text-slate-400 text-xs">▼</div>
                </button>
                {isDropdownOpen && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-slate-100 rounded-xl shadow-lg overflow-hidden py-1">
                    {(['Administrator', 'Field Executive', 'Shop Owner'] as const).map((r) => (
                      <button
                        key={r}
                        type="button"
                        onClick={() => handleSelectRole(r)}
                        className={`w-full text-left px-4 py-2.5 text-sm transition-colors ${role === r ? 'bg-emerald-50 text-emerald-700 font-medium' : 'text-slate-700 hover:bg-slate-50'}`}
                      >
                        {r}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Username Input */}
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Username / Admin ID</label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="ADMIN"
                required
                className="w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all"
              />
            </div>

            {/* Password Input */}
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                required
                className="w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all"
              />
            </div>

            <button
              type="submit"
              disabled={loading || !password}
              className="w-full bg-emerald-700 hover:bg-emerald-800 text-white font-semibold py-3.5 rounded-xl transition-all shadow-sm active:scale-[0.98] disabled:opacity-70 flex justify-center mt-6 cursor-pointer"
            >
              {loading ? 'Authenticating...' : 'Sign In with Password'}
            </button>
          </form>
        ) : !otpRequested ? (
          /* Step 1: Request OTP */
          <form onSubmit={handleSendOtp} className="space-y-5">
            {/* Role Selection */}
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Select Role</label>
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                  className="w-full bg-slate-50 border border-slate-200 text-left px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all text-slate-800 font-medium flex items-center justify-between"
                >
                  {role}
                  <div className="text-slate-400 text-xs">▼</div>
                </button>
                {isDropdownOpen && (
                  <div className="absolute z-10 w-full mt-1 bg-white border border-slate-100 rounded-xl shadow-lg overflow-hidden py-1">
                    {(['Administrator', 'Field Executive', 'Shop Owner'] as const).map((r) => (
                      <button
                        key={r}
                        type="button"
                        onClick={() => handleSelectRole(r)}
                        className={`w-full text-left px-4 py-2.5 text-sm transition-colors ${role === r ? 'bg-emerald-50 text-emerald-700 font-medium' : 'text-slate-700 hover:bg-slate-50'}`}
                      >
                        {r}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>

            {/* Username Input */}
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Username / Login ID</label>
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="e.g. ADMIN"
                required
                className="w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all"
              />
            </div>

            {/* Mobile Number Input */}
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Registered Mobile Number</label>
              <div className="relative">
                <div className="absolute inset-y-0 left-0 pl-3.5 flex items-center pointer-events-none text-slate-400 font-semibold text-sm">
                  +91
                </div>
                <input
                  type="tel"
                  value={mobile}
                  onChange={(e) => setMobile(e.target.value)}
                  placeholder="98765 43210"
                  maxLength={10}
                  required
                  className="w-full pl-14 pr-4 py-3 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all font-medium text-slate-800"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-emerald-700 hover:bg-emerald-800 text-white font-semibold py-3.5 rounded-xl transition-all shadow-sm active:scale-[0.98] disabled:opacity-70 flex items-center justify-center gap-2 mt-6 cursor-pointer"
            >
              {loading ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  <span>Requesting OTP...</span>
                </>
              ) : (
                <>
                  <span>Send OTP</span>
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </form>
        ) : (
          /* Step 2: Verify OTP */
          <form onSubmit={handleVerify} className="space-y-5">
            <div>
              <label className="block text-sm font-semibold text-slate-700 mb-1.5">Enter 6-Digit OTP</label>
              <div className="relative">
                <input
                  type="text"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                  placeholder="••••••"
                  maxLength={6}
                  autoFocus
                  required
                  className="w-full bg-slate-50 border border-slate-200 px-4 py-3 rounded-xl text-center text-2xl tracking-widest font-mono font-bold focus:outline-none focus:ring-2 focus:ring-emerald-500/20 focus:border-emerald-500 transition-all"
                />
                <KeyRound className="w-4 h-4 absolute right-3.5 top-4 text-slate-400" />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading || otp.length < 6}
              className="w-full bg-emerald-700 hover:bg-emerald-800 text-white font-semibold py-3.5 rounded-xl transition-all shadow-sm active:scale-[0.98] disabled:opacity-70 flex items-center justify-center gap-2 mt-6 cursor-pointer"
            >
              {loading ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  <span>Verifying with Backend...</span>
                </>
              ) : (
                <span>Verify & Login</span>
              )}
            </button>

            <button
              type="button"
              disabled={loading}
              onClick={() => {
                cleanupRecaptchaVerifier('recaptcha-container');
                setOtpRequested(false);
                setConfirmationResult(null);
                setOtp('');
                setError(null);
                setSuccessMsg(null);
              }}
              className="w-full text-slate-500 hover:text-slate-700 text-sm font-medium py-2 transition-colors cursor-pointer text-center"
            >
              Change Username / Mobile Number
            </button>
          </form>
        )}

        {/* Presets Row */}
        {!otpRequested && (
          <div className="mt-8 pt-6 border-t border-slate-100">
            <p className="text-xs text-center text-slate-400 font-bold tracking-wider mb-4 uppercase">Test Presets</p>
            <div className="flex gap-2 justify-center">
              <button
                type="button"
                onClick={() => handleSelectRole('Administrator')}
                className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
                  role === 'Administrator' ? 'bg-emerald-100 text-emerald-800' : 'border border-slate-200 text-slate-500 hover:bg-slate-50'
                }`}
              >
                Admin
              </button>
              <button
                type="button"
                onClick={() => handleSelectRole('Field Executive')}
                className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
                  role === 'Field Executive' ? 'bg-emerald-100 text-emerald-800' : 'border border-slate-200 text-slate-500 hover:bg-slate-50'
                }`}
              >
                Field Exec
              </button>
              <button
                type="button"
                onClick={() => handleSelectRole('Shop Owner')}
                className={`px-4 py-1.5 rounded-lg text-xs font-semibold transition-colors cursor-pointer ${
                  role === 'Shop Owner' ? 'bg-emerald-100 text-emerald-800' : 'border border-slate-200 text-slate-500 hover:bg-slate-50'
                }`}
              >
                Shop Owner
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
