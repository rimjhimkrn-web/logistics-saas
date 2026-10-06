'use client';

import React, { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createAuthClient } from '@/lib/auth/supabase-client';

export default function AccountRecoveryPage() {
  const [recoveryCode, setRecoveryCode] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const router = useRouter();
  const supabase = createAuthClient();

  const handleRecovery = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      // Validate emergency single-use code against audit RPC backend
      const { data, error } = await supabase.rpc('verify_emergency_recovery_code', {
        p_code: recoveryCode.trim(),
      });

      if (error || !data?.success) {
        throw new Error(error?.message || 'Invalid or previously used emergency backup code.');
      }

      // Force-unenroll current broken TOTP factors
      const { data: factors } = await supabase.auth.mfa.listFactors();
      if (factors?.totp) {
        for (const factor of factors.totp) {
          await supabase.auth.mfa.unenroll({ factorId: factor.id });
        }
      }

      // Redirect user directly to force re-enrollment
      router.push('/mfa/enroll?reason=recovery_reset');

    } catch (err: any) {
      setErrorMessage(err.message || 'Emergency recovery failed. Contact KRIM Ops Security Support.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full max-w-md p-8 bg-[#0f172a] border border-rose-500/20 rounded-2xl shadow-2xl">
      <div className="mb-6 text-center">
        <div className="w-12 h-12 mx-auto mb-3 bg-rose-500/10 border border-rose-500/30 rounded-full flex items-center justify-center text-xl text-rose-400">
          🚨
        </div>
        <h1 className="text-xl font-extrabold text-white tracking-tight">Emergency Account Recovery</h1>
        <p className="mt-2 text-xs text-slate-400">
          Enter one of your 12-character single-use emergency backup codes generated during MFA enrollment.
        </p>
      </div>

      <form onSubmit={handleRecovery} className="space-y-4">
        {errorMessage && (
          <div className="p-3 bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs rounded-lg">
            {errorMessage}
          </div>
        )}

        <div className="space-y-1">
          <label className="block text-[11px] font-mono text-slate-400 uppercase">Backup Key Code</label>
          <input
            type="text"
            required
            value={recoveryCode}
            onChange={(e) => setRecoveryCode(e.target.value.toUpperCase())}
            placeholder="XXXX-XXXX-XXXX"
            className="w-full px-3 py-2.5 bg-[#0b1329] border border-white/10 rounded-lg text-center text-base font-mono text-amber-400 tracking-wider focus:outline-none focus:border-amber-400"
          />
        </div>

        <button
          type="submit"
          disabled={!recoveryCode || isSubmitting}
          className="w-full py-3 bg-gradient-to-r from-rose-500 to-amber-600 text-white font-bold text-xs rounded-lg uppercase tracking-wider hover:opacity-90 disabled:opacity-30 transition-all"
        >
          {isSubmitting ? 'Bypassing MFA Factor...' : 'Verify Backup Code & Reset MFA →'}
        </button>
      </form>
    </div>
  );
}
