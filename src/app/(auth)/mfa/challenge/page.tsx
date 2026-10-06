'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { createAuthClient } from '@/lib/auth/supabase-client';

export default function MfaChallengePage() {
  const [code, setCode] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const router = useRouter();
  const supabase = createAuthClient();

  const handleVerify = async (e: React.FormEvent) => {
    e.preventDefault();
    if (code.length !== 6) return;

    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      // Fetch list of factors
      const { data: factors, error: factorsError } = await supabase.auth.mfa.listFactors();
      if (factorsError) throw factorsError;

      const totpFactor = factors.totp[0];
      if (!totpFactor) {
        throw new Error('No enrolled TOTP factor found for this account.');
      }

      // Create Challenge
      const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({
        factorId: totpFactor.id,
      });
      if (challengeError) throw challengeError;

      // Verify Challenge
      const { error: verifyError } = await supabase.auth.mfa.verify({
        factorId: totpFactor.id,
        challengeId: challenge.id,
        code: code,
      });

      if (verifyError) throw verifyError;

      // Elevate session to AAL2 complete
      router.push('/dashboard');

    } catch (err: any) {
      setErrorMessage(err.message || 'Verification failed. Invalid code.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full max-w-md p-8 bg-[#0f172a] border border-white/10 rounded-2xl shadow-2xl text-center">
      <div className="w-12 h-12 mx-auto mb-4 bg-cyan-500/10 border border-cyan-500/30 rounded-full flex items-center justify-center text-xl text-cyan-400">
        🛡️
      </div>

      <h1 className="text-xl font-extrabold text-white tracking-tight">MFA Verification Required</h1>
      <p className="mt-2 text-xs text-slate-400">
        Your account profile requires Authenticator Assurance Level 2 (AAL2). Enter code from Google Authenticator / Authy.
      </p>

      <form onSubmit={handleVerify} className="mt-6 space-y-4">
        {errorMessage && (
          <div className="p-3 bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs rounded-lg">
            {errorMessage}
          </div>
        )}

        <input
          type="text"
          maxLength={6}
          autoFocus
          value={code}
          onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
          placeholder="000000"
          className="w-full py-3 text-center text-2xl font-mono tracking-[0.5em] bg-[#0b1329] border border-white/10 rounded-xl text-cyan-400 focus:outline-none focus:border-cyan-400"
        />

        <button
          type="submit"
          disabled={code.length !== 6 || isSubmitting}
          className="w-full py-3 bg-gradient-to-r from-cyan-500 to-blue-600 text-white font-bold text-xs rounded-lg uppercase tracking-wider hover:opacity-90 disabled:opacity-30 transition-all"
        >
          {isSubmitting ? 'Verifying Challenge...' : 'Authenticate AAL2 Session →'}
        </button>

        <div className="pt-4 border-t border-white/10 flex justify-between items-center text-[11px] font-mono">
          <Link className="text-slate-400 hover:text-cyan-400" href="/recovery">
            Lost Authenticator?
          </Link>
          <Link className="text-rose-400 hover:underline" href="/sign-in">
            Cancel Sign In
          </Link>
        </div>
      </form>
    </div>
  );
}
