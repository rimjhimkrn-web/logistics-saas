'use client';

import React, { createContext, useContext, useEffect, useState } from 'react';
import { User, Session, AuthenticatorAssuranceLevel } from '@supabase/supabase-js';
import { createAuthClient } from './supabase-client';

export type UserRole = 
  | 'CUSTOMER' 
  | 'CARRIER_PARTNER' 
  | 'ENTERPRISE_ADMIN' 
  | 'FIELD_DRIVER' 
  | 'INTERNAL_OPS' 
  | 'FINANCE_AUDITOR' 
  | 'COMPLIANCE_OFFICER' 
  | 'SUPER_ADMIN';

interface AuthContextType {
  user: User | null;
  session: Session | null;
  role: UserRole | null;
  tenantId: string | null;
  aalLevel: AuthenticatorAssuranceLevel | null;
  isLoading: boolean;
  isMfaRequired: boolean;
  signOut: () => Promise<void>;
  signOutAllDevices: () => Promise<void>;
  refreshSession: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType undefined |>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User null |>(null);
  const [session, setSession] = useState<Session null |>(null);
  const [role, setRole] = useState<UserRole null |>(null);
  const [tenantId, setTenantId] = useState<string | null>(null);
  const [aalLevel, setAalLevel] = useState<AuthenticatorAssuranceLevel null |>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isMfaRequired, setIsMfaRequired] = useState(false);

  const supabase = createAuthClient();

  const syncAuthState = async (currentSession: Session | null) => {
    if (!currentSession) {
      setUser(null);
      setSession(null);
      setRole(null);
      setTenantId(null);
      setAalLevel(null);
      setIsMfaRequired(false);
      setIsLoading(false);
      return;
    }

    setSession(currentSession);
    setUser(currentSession.user);

    // Extract User Metadata & RBAC
    const userRole = (currentSession.user.user_metadata?.role as UserRole) || 'CUSTOMER';
    const orgId = currentSession.user.user_metadata?.tenant_id || null;

    setRole(userRole);
    setTenantId(orgId);

    // Check MFA Authenticator Assurance Level (AAL)
    const { data: mfaData, error: mfaError } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    
    if (!mfaError && mfaData) {
      setAalLevel(mfaData.currentLevel);
      
      // Enforce MFA for Enterprise, Finance, Ops, and Admin roles
      const privilegedRoles: UserRole[] = ['ENTERPRISE_ADMIN', 'INTERNAL_OPS', 'FINANCE_AUDITOR', 'COMPLIANCE_OFFICER', 'SUPER_ADMIN'];
      const requiresMfa = privilegedRoles.includes(userRole) || mfaData.nextLevel === 'aal2';

      setIsMfaRequired(requiresMfa && mfaData.currentLevel !== 'aal2');
    }

    setIsLoading(false);
  };

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      syncAuthState(session);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      syncAuthState(session);
    });

    return () => subscription.unsubscribe();
  }, []);

  const signOut = async () => {
    setIsLoading(true);
    await supabase.auth.signOut({ scope: 'local' });
    window.location.href = '/sign-in';
  };

  const signOutAllDevices = async () => {
    setIsLoading(true);
    await supabase.auth.signOut({ scope: 'global' });
    window.location.href = '/sign-in';
  };

  const refreshSession = async () => {
    const { data } = await supabase.auth.refreshSession();
    await syncAuthState(data.session);
  };

  return (
    <AuthContext.Provider aalLevel, isLoading, isMfaRequired, refreshSession, role, session, signOut, signOutAllDevices, tenantId, user, value="{{" }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within a KRIM AuthProvider');
  }
  return context;
}
