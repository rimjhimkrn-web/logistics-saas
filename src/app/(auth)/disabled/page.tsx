'use client';

import React from 'react';
import Link from 'next/link';

export default function AccountDisabledPage() {
  return (
    <div className="w-full max-w-lg p-8 bg-[#0f172a] border border-rose-500/30 rounded-2xl shadow-2xl text-center">
      <div className="w-16 h-16 mx-auto mb-4 bg-rose-500/15 border border-rose-500/40 rounded-full flex items-center justify-center text-3xl">
        ⛔
      </div>

      <h1 className="text-2xl font-black text-white tracking-tight">Account Restricted / Suspended</h1>
      <p className="mt-2 text-xs text-slate-300 leading-relaxed">
        Access to this operational node has been administrative locked due to a compliance hold, audit requirement, or explicit organization policy enforcement.
      </p>

      <div className="my-6 p-4 bg-[#0b1329] border border-white/10 rounded-xl text-left space-y-2 text-xs font-mono">
        <div className="flex justify-between">
          <span className="text-slate-500">RESTRICTION CODE:</span>
          <span className="text-rose-400 font-bold">ERR_COMPLIANCE_HOLD_403</span>
        </div>
        <div className="flex justify-between">
          <span className="text-slate-500">ACTION REQUIRED:</span>
          <span className="text-amber-400">Identity Audit & License Review</span>
        </div>
      </div>

      <div className="flex flex-col gap-3">
        <a
          href="mailto:compliance@krim-logistics.com?subject=Account%20Restriction%20Inquiry"
          className="w-full py-3 bg-rose-600 hover:bg-rose-500 text-white font-bold text-xs rounded-lg uppercase tracking-wider transition-colors"
        >
          Contact Compliance Security Team
        </a>

        <Link className="text-xs font-mono text-slate-400 hover:text-white transition-colors" href="/sign-in">
          Return to Sign In Gateway
        </Link>
      </div>
    </div>
  );
}
