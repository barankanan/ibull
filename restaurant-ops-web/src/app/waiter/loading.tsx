export default function WaiterLoading() {
  return (
    <div className="min-h-screen animate-pulse bg-mesh-shell px-4 py-6 md:px-6">
      <div className="mx-auto max-w-[1600px] space-y-6">
        <div className="grid gap-4 xl:grid-cols-[1.25fr,0.75fr]">
          <div className="h-72 rounded-[32px] bg-slate-200/70" />
          <div className="h-72 rounded-[32px] bg-slate-200/70" />
        </div>
        <div className="h-24 rounded-[28px] bg-white/70" />
        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }).map((_, index) => (
            <div key={index} className="h-72 rounded-[28px] bg-white/70" />
          ))}
        </div>
      </div>
    </div>
  );
}
