export function Logo() {
  return (
    <div className="logo" aria-label="trAIning">
      <span className="logo-mark" aria-hidden="true">
        <svg viewBox="0 0 100 100">
          <rect x="15" y="26" width="70" height="48" rx="24" fill="none" stroke="#C8F05A" strokeWidth="6" />
          <rect x="24" y="35" width="52" height="30" rx="15" fill="none" stroke="#C8F05A" strokeOpacity=".35" strokeWidth="2.5" />
          <circle cx="76" cy="31" r="5" fill="#EDEFF2" />
        </svg>
      </span>
      <span className="logo-word" aria-hidden="true">
        TR<span>AI</span>NING
      </span>
    </div>
  )
}
