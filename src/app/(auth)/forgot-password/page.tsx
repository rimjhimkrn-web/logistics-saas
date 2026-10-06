'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { createAuthClient } from '@/lib/auth/supabase-client';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const supabase = createAuthClient();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      const redirectUrl = `${window.location.origin}/reset-password`;

      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: redirectUrl,
      });

      if (error) throw error;

      setIsSubmitted(true);
    } catch (err: any) {
      setErrorMessage(err.message || 'Unable to process reset request. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full max-w-md p-8 bg-[#0f172a] border border-white/10 rounded-2xl shadow-2xl">
      <div className="mb-6 text-center">
        <h1 className="text-xl font-extrabold text-white tracking-tight">Request Password Reset</h1>
        <p className="mt-2 text-xs text-slate-400">
          Enter your verified enterprise identity email to receive a secure credentials recovery token.
        </p>
      </div>

      {isSubmitted ? (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-center">
          <div className="text-2xl mb-2">✉️</div>
          <h3 className="text-sm font-bold text-emerald-400">Recovery Instructions Transmitted</h3>
          <p className="mt-1 text-xs text-slate-300">
            If an active account exists for <span className="font-mono text-cyan-400">{email}</span>, a reset link has been dispatched.
          </p>
          <div className="mt-6">
            <Link className="inline-block text-xs font-mono font-bold text-cyan-400 hover:underline" href="/sign-in">
              ← Return to Identity Gateway
            </Link>
          </div>
        </div>
      ) : (
        <form onSubmit={handleSubmit} className="space-y-4">
          {errorMessage && (
            <div className="p-3 bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs rounded-lg">
              {errorMessage}
            </div>
          )}

          <div className="space-y-1">
            <label htmlFor="email" className="block text-[11px] font-mono text-slate-400 uppercase">
              Registered Work Email
            </label>
            <input
              id="email"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="operator@krim-logistics.com"
              className="w-full px-3 py-2.5 bg-[#0b1329] border border-white/10 rounded-lg text-sm text-white focus:outline-none focus:border-cyan-400 font-sans"
            />
          </div>

          <button
            type="submit"
            disabled={isSubmitting}
            className="w-full py-3 bg-gradient-to-r from-cyan-500 to-blue-600 text-white font-bold text-xs rounded-lg uppercase tracking-wider hover:opacity-90 disabled:opacity-50 transition-all"
          >
            {isSubmitting ? 'Transmitting Token...' : 'Send Recovery Link →'}
          </button>

          <div className="pt-4 border-t border-white/10 text-center">
            <Link className="text-xs font-mono text-slate-400 hover:text-white transition-colors" href="/sign-in">
              Remembered your password? Sign In
            </Link>
          </div>
        </form>
      )}
    </div>
  );
}
