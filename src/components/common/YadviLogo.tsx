import React from 'react';

interface YadviLogoProps {
  size?: 'sm' | 'md' | 'lg' | 'xl';
  showTagline?: boolean;
  variant?: 'dark' | 'light' | 'white';
}

export const YadviLogo: React.FC<YadviLogoProps> = ({
  size = 'md',
  showTagline = true,
  variant = 'dark',
}) => {
  const isLight = variant === 'light' || variant === 'white';

  const iconSizes = {
    sm: 'w-7 h-7',
    md: 'w-10 h-10',
    lg: 'w-14 h-14',
    xl: 'w-20 h-20',
  };

  const titleSizes = {
    sm: 'text-base font-bold tracking-tight',
    md: 'text-xl font-black tracking-tight',
    lg: 'text-2xl font-black tracking-normal',
    xl: 'text-3xl font-black tracking-wide',
  };

  const subtitleSizes = {
    sm: 'text-[9px] tracking-widest font-semibold',
    md: 'text-[11px] tracking-widest font-semibold',
    lg: 'text-[13px] tracking-widest font-semibold',
    xl: 'text-[15px] tracking-widest font-semibold',
  };

  return (
    <div className="flex items-center gap-3 select-none">
      {/* Emblem */}
      <div className={`relative flex items-center justify-center ${iconSizes[size]} shrink-0`}>
        <img
          src="/yhs_logo.png"
          alt="YHS Seeds Logo"
          className="w-full h-full object-contain"
        />
      </div>

      {/* Brand Text */}
      <div className="flex flex-col leading-none">
        <div className="flex items-center gap-1.5">
          <span className={`${titleSizes[size]} ${isLight ? 'text-white' : 'text-slate-900'} font-black`}>
            YADVI
          </span>
          <span className={`px-1.5 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider ${
            isLight ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-400/30' : 'bg-emerald-100 text-emerald-800'
          }`}>
            Seeds
          </span>
        </div>
        <span className={`${subtitleSizes[size]} ${isLight ? 'text-emerald-300' : 'text-yadvi-primary'} font-bold mt-0.5 uppercase`}>
          HYBRID SEEDS
        </span>
        {showTagline && size !== 'sm' && (
          <span className={`text-[10px] font-medium tracking-tight mt-1 ${isLight ? 'text-emerald-100/70' : 'text-slate-500'}`}>
            Growing Together, Harvesting the Future
          </span>
        )}
      </div>
    </div>
  );
};
