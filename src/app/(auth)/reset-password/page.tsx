'use client';

import React, { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { createAuthClient } from '@/lib/auth/supabase-client';

export default function ResetPasswordPage() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState(false);

  const router = useRouter();
  const supabase = createAuthClient();

  // Password Requirements Validation
  const hasMinLength = password.length >= 12;
  const hasUppercase = /[A-Z]/.test(password);
  const hasLowercase = /[a-z]/.test(password);
  const hasNumber = /[0-9]/.test(password);
  const hasSpecial = /[^A-Za-z0-9]/.test(password);
  const isMatching = password === confirmPassword && confirmPassword.length > 0;

  const isPasswordValid = hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecial && isMatching;

  const handlePasswordUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!isPasswordValid) return;

    setIsSubmitting(true);
    setErrorMessage(null);

    try {
      const { error } = await supabase.auth.updateUser({
        password: password,
      });

      if (error) throw error;

      setSuccessMessage(true);
      
      // Revoke all existing sessions and demand clean re-authentication
      setTimeout(async () => {
        await supabase.auth.signOut({ scope: 'global' });
        router.push('/sign-in?reset=success');
      }, 2500);

    } catch (err: any) {
      setErrorMessage(err.message || 'Failed to update credentials. Reset token may have expired.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="w-full max-w-md p-8 bg-[#0f172a] border border-white/10 rounded-2xl shadow-2xl">
      <div className="mb-6 text-center">
        <h1 className="text-xl font-extrabold text-white tracking-tight">Set New Account Credentials</h1>
        <p className="mt-2 text-xs text-slate-400">
          Enforcing KRIM OS Security Standard: Minimum 12 characters with multi-character class entropy.
        </p>
      </div>

      {successMessage ? (
        <div className="p-4 bg-emerald-500/10 border border-emerald-500/30 rounded-xl text-center">
          <div className="text-2xl mb-2">🔒</div>
          <h3 className="text-sm font-bold text-emerald-400">Credentials Updated Successfully</h3>
          <p className="mt-1 text-xs text-slate-300">
            Revoking all active global device sessions. Redirecting to Gateway...
          </p>
        </div>
      ) : (
        <form onSubmit={handlePasswordUpdate} className="space-y-4">
          {errorMessage && (
            <div className="p-3 bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs rounded-lg">
              {errorMessage}
            </div>
          )}

          <div className="space-y-1">
            <label className="block text-[11px] font-mono text-slate-400 uppercase">New Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••••••"
              className="w-full px-3 py-2.5 bg-[#0b1329] border border-white/10 rounded-lg text-sm text-white focus:outline-none focus:border-cyan-400 font-mono"
            />
          </div>

          <div className="space-y-1">
            <label className="block text-[11px] font-mono text-slate-400 uppercase">Confirm New Password</label>
            <input
              type="password"
              required
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
              placeholder="••••••••••••"
              className="w-full px-3 py-2.5 bg-[#0b1329] border border-white/10 rounded-lg text-sm text-white focus:outline-none focus:border-cyan-400 font-mono"
            />
          </div>

          {/* Real-time Complexity Checklist */}
          <div className="p-3 bg-[#0b1329] rounded-lg border border-white/5 space-y-1 text-[11px] font-mono">
            <div className={hasMinLength ? 'text-emerald-400' : 'text-slate-500'}>
              {hasMinLength ? '✓' : '○'} Min. 12 Characters
            </div>
            <div className={hasUppercase && hasLowercase ? 'text-emerald-400' : 'text-slate-500'}>
              {hasUppercase && hasLowercase ? '✓' : '○'} Mixed Upper & Lower Case
            </div>
            <div className={hasNumber && hasSpecial ? 'text-emerald-400' : 'text-slate-500'}>
              {hasNumber && hasSpecial ? '✓' : '○'} Numbers & Symbols Included
            </div>
            <div className={isMatching ? 'text-emerald-400' : 'text-slate-500'}>
              {isMatching ? '✓' : '○'} Passwords Match
            </div>
          </div>

          <button
            type="submit"
            disabled={!isPasswordValid || isSubmitting}
            className="w-full py-3 bg-gradient-to-r from-cyan-500 to-blue-600 text-white font-bold text-xs rounded-lg uppercase tracking-wider hover:opacity-90 disabled:opacity-30 transition-all"
          >
            {isSubmitting ? 'Updating Credentials...' : 'Secure & Update Password →'}
          </button>
        </form>
      )}
    </div>
  );
      }
