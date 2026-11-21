"use client";
import { CdnImg } from "@/components/CdnImg";
import { useState } from "react";
import { Edit2, Check, X, Medal as MedalIcon } from "lucide-react";
import { updateMedalConfig } from "@/lib/actions/medals";
import { toast } from "sonner";
interface MedalTableProps {
  initialMedals: any[];
}
export function MedalTable({ initialMedals }: MedalTableProps) {
  const [medals, setMedals] = useState(initialMedals);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editData, setEditData] = useState<any>(null);
  const handleEdit = (medal: any) => {
    setEditingId(medal.id);
    setEditData({ ...medal });
  };
  const handleSave = async () => {
    try {
      const { id, name, image_url, ...updateData } = editData;
      await updateMedalConfig(id, {
        required_wealth_value: updateData.required_wealth_value,
        required_charm_value: updateData.required_charm_value,
      });
      setMedals(medals.map((m) => (m.id === id ? { ...m, ...updateData } : m)));
      setEditingId(null);
      toast.success(`${name} requirements updated`);
    } catch (error: any) {
      toast.error(error.message);
    }
  };
  return (
    <div className="space-y-6">
      <div className="glass-card p-0 overflow-hidden border border-white/5 shadow-2xl">
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="bg-white/5 border-b border-white/5">
                <th className="px-6 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Medal
                </th>
                <th className="px-6 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Name
                </th>
                <th className="px-6 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Wealth Req
                </th>
                <th className="px-6 py-4 text-[10px] font-black uppercase tracking-widest text-white/30">
                  Charm Req
                </th>
                <th className="px-6 py-4 text-[10px] font-black uppercase tracking-widest text-white/30 text-right">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
              {medals.map((medal) => {
                const isEditing = editingId === medal.id;
                return (
                  <tr key={medal.id} className="hover:bg-white/[0.02] transition-colors group">
                    <td className="px-6 py-4">
                      <div className="w-12 h-12 rounded-xl bg-black/40 border border-white/5 p-2 flex items-center justify-center">
                        <CdnImg
                          src={medal.image_url}
                          alt={medal.name}
                          className="w-full h-full object-contain"
                        />
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <span className="text-sm font-bold text-white/80">{medal.name}</span>
                    </td>
                    <td className="px-6 py-4">
                      {isEditing ? (
                        <input
                          type="number"
                          value={editData.required_wealth_value || 0}
                          onChange={(e) =>
                            setEditData({
                              ...editData,
                              required_wealth_value: parseInt(e.target.value),
                            })
                          }
                          className="bg-black/40 border border-white/10 rounded px-2 py-1 w-full text-white font-mono"
                        />
                      ) : (
                        <span className="text-sm font-mono text-amber-500/60">
                          {(medal.required_wealth_value || 0).toLocaleString()} Wealth
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4">
                      {isEditing ? (
                        <input
                          type="number"
                          value={editData.required_charm_value || 0}
                          onChange={(e) =>
                            setEditData({
                              ...editData,
                              required_charm_value: parseInt(e.target.value),
                            })
                          }
                          className="bg-black/40 border border-white/10 rounded px-2 py-1 w-full text-white font-mono"
                        />
                      ) : (
                        <span className="text-sm font-mono text-pink-500/60">
                          {(medal.required_charm_value || 0).toLocaleString()} Charm
                        </span>
                      )}
                    </td>

                    <td className="px-6 py-4 text-right">
                      <div className="flex items-center justify-end gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        {isEditing ? (
                          <>
                            <button
                              onClick={handleSave}
                              className="p-2 bg-green-500/20 text-green-400 rounded-lg hover:bg-green-500/40 transition-colors"
                            >
                              <Check size={16} />
                            </button>
                            <button
                              onClick={() => setEditingId(null)}
                              className="p-2 bg-red-500/20 text-red-400 rounded-lg hover:bg-red-500/40 transition-colors"
                            >
                              <X size={16} />
                            </button>
                          </>
                        ) : (
                          <button
                            onClick={() => handleEdit(medal)}
                            className="p-2 bg-white/5 text-white/40 rounded-lg hover:bg-white/10 hover:text-white transition-colors"
                          >
                            <Edit2 size={16} />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
