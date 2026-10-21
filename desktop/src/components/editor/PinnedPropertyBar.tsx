import React from 'react';
import { ShieldCheck, Lock, Unlock, Shield } from 'lucide-react';
import { useBlockStore } from '../../store/useBlockStore';
import { Block } from '../../types/models';

interface PinnedPropertyBarProps {
  doc: Block;
}

export const PinnedPropertyBar: React.FC<PinnedPropertyBarProps> = ({ doc }) => {
  const { setDocumentLock, setDocumentVerification } = useBlockStore();

  const isLocked = Boolean(doc.isLocked);
  const isVerified = Boolean(
    doc.verifiedAt && (!doc.verifiedExpiresAt || new Date(doc.verifiedExpiresAt) > new Date())
  );

  const calculateDaysRemaining = (expiresAt?: string | null) => {
    if (!expiresAt) return 0;
    const diff = new Date(expiresAt).getTime() - Date.now();
    return Math.max(0, Math.ceil(diff / (1000 * 60 * 60 * 24)));
  };

  const daysRemaining = calculateDaysRemaining(doc.verifiedExpiresAt);

  return (
    <div className="flex items-center gap-2 py-2 border-b border-white/[0.06] mb-4 overflow-x-auto text-xs select-none">
      {/* 1. Authoritative Verification Pill */}
      <button
        disabled={isLocked}
        onClick={() => setDocumentVerification(doc.id, isVerified ? 365 : 90, 'Author')}
        className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full font-semibold transition cursor-pointer ${
          isVerified
            ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 hover:bg-emerald-500/25'
            : 'bg-white/[0.05] text-slate-400 border border-white/[0.08] hover:bg-white/[0.08] hover:text-slate-200'
        }`}
        title={
          isVerified
            ? `Verified by ${doc.verifiedBy || 'Author'} (${daysRemaining}d remaining). Click to renew.`
            : 'Click to mark note as authoritative (90 days).'
        }
      >
        {isVerified ? (
          <>
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>Verified ({daysRemaining}d)</span>
          </>
        ) : (
          <>
            <Shield className="w-3.5 h-3.5" />
            <span>Verify Note</span>
          </>
        )}
      </button>

      {/* 2. Document Lock Mode Pill */}
      <button
        onClick={() => setDocumentLock(doc.id, !isLocked)}
        className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full font-semibold transition cursor-pointer ${
          isLocked
            ? 'bg-orange-500/15 text-orange-400 border border-orange-500/30 hover:bg-orange-500/25'
            : 'bg-white/[0.05] text-slate-400 border border-white/[0.08] hover:bg-white/[0.08] hover:text-slate-200'
        }`}
        title={isLocked ? 'Document is locked. Click to unlock.' : 'Click to lock against edits.'}
      >
        {isLocked ? (
          <>
            <Lock className="w-3.5 h-3.5" />
            <span>Locked (Read-Only)</span>
          </>
        ) : (
          <>
            <Unlock className="w-3.5 h-3.5" />
            <span>Lock Note</span>
          </>
        )}
      </button>
    </div>
  );
};
