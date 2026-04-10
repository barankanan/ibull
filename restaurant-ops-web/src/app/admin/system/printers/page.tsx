import { EmptyState } from "@/components/ui/EmptyState";
import { Panel } from "@/components/ui/Panel";
import { getRestaurantServerRepository } from "@/features/restaurant/server/repository";
import { formatCurrency, formatShortDate } from "@/lib/utils";

export default async function AdminPrintersPage() {
  const repository = getRestaurantServerRepository();
  const snapshot = await repository.getSnapshot();
  const printerJobs = snapshot.snapshot.printerJobs;

  return (
    <div className="min-h-screen px-4 py-6 md:px-6">
      <div className="mx-auto max-w-6xl space-y-6">
        <Panel className="overflow-hidden bg-gradient-to-br from-slate-950 via-slate-900 to-violet-900 p-6 text-white">
          <div className="text-xs uppercase tracking-[0.22em] text-white/55">
            Admin / Sistem / Yazici Ayarlari
          </div>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight">
            Adisyon ve mutfak cikti kayitlari
          </h1>
          <p className="mt-3 max-w-3xl text-sm leading-6 text-white/75">
            Garson tarafinda olusan otomatik ve manuel print job kayitlari burada
            izlenir. Yeniden yazdirma ve cihaz entegrasyonu icin veri omurgasi bu
            listeye dayanir.
          </p>
        </Panel>

        {printerJobs.length === 0 ? (
          <EmptyState
            title="Yazdirma kaydi bulunamadi"
            description="Siparis gonderimi veya manuel yazdirma olustugunda print job listesi burada dolacaktir."
          />
        ) : (
          <div className="space-y-4">
            {printerJobs.map((job) => (
              <Panel key={job.id} className="p-5">
                <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-medium text-slate-700">
                        {job.printType === "adisyon" ? "Adisyon" : "Mutfak"}
                      </span>
                      <span className="rounded-full bg-violet-50 px-3 py-1 text-xs font-medium text-violet-800">
                        {job.status}
                      </span>
                      <span className="rounded-full bg-amber-50 px-3 py-1 text-xs font-medium text-amber-800">
                        {job.source === "auto_on_submit" ? "Otomatik" : "Manuel"}
                      </span>
                    </div>
                    <div className="mt-3 text-xl font-semibold text-slate-950">
                      {job.tableName} • {job.orderReference ?? "Siparis"}
                    </div>
                    <div className="mt-1 text-sm text-slate-500">
                      {formatShortDate(job.createdAt)} • {job.requestedBy ?? "Bilinmiyor"} •{" "}
                      {job.printerTarget ?? "Varsayilan yazici"}
                    </div>
                  </div>
                  <div className="rounded-[22px] bg-slate-50 px-4 py-3 text-right">
                    <div className="text-xs uppercase tracking-[0.18em] text-slate-400">
                      Toplam
                    </div>
                    <div className="mt-1 text-lg font-semibold text-slate-950">
                      {formatCurrency(job.totalAmount)}
                    </div>
                  </div>
                </div>

                <div className="mt-4 grid gap-2 md:grid-cols-2">
                  {job.items.map((item) => (
                    <div
                      key={item.id}
                      className="rounded-[20px] border border-slate-200 bg-white px-4 py-3 text-sm text-slate-600"
                    >
                      <span className="font-medium text-slate-950">{item.name}</span> •{" "}
                      {item.quantity} adet • {formatCurrency(item.totalPrice)}
                    </div>
                  ))}
                </div>
              </Panel>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
