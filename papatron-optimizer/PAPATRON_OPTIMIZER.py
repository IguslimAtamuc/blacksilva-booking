"""PAPATRON OPTIMIZER — task manager, optimizator si scaner antivirus.

Interfata: Dark Theme cu rosu. Ruleaza pe Windows (recomandat ca Administrator).
"""

import os
import threading
import tkinter as tk
from tkinter import messagebox, ttk

import customtkinter as ctk

from core import antivirus, monitor, optimizer

# ---------------------------------------------------------------- culori tema
ROSU = "#e3242b"
ROSU_HOVER = "#ff3b42"
ROSU_INCHIS = "#7a1014"
FUNDAL = "#0d0d0f"
PANOU = "#17171a"
PANOU_2 = "#1f1f24"
TEXT = "#f2f2f2"
TEXT_SLAB = "#9a9aa0"
VERDE = "#2ecc71"
GALBEN = "#f1c40f"

ctk.set_appearance_mode("dark")

INTERVAL_REFRESH_MS = 2000


class PapatronOptimizer(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("PAPATRON OPTIMIZER")
        self.geometry("1180x760")
        self.minsize(980, 640)
        self.configure(fg_color=FUNDAL)

        self.pids_optimizate: list[int] = []
        self.scanare_in_curs = False
        self.var_aplicatie_aleasa = tk.StringVar(value="")
        self.checkbox_inchidere: dict[str, tuple[ctk.CTkCheckBox, list[int]]] = {}
        self.aplicatii_curente: dict[str, list[int]] = {}

        self._stil_tabele()
        self._construieste_header()
        self._construieste_taburi()
        self.after(300, self._refresh_periodic)

    # ------------------------------------------------------------------ stil
    def _stil_tabele(self):
        stil = ttk.Style(self)
        stil.theme_use("clam")
        stil.configure("Papatron.Treeview",
                       background=PANOU, fieldbackground=PANOU, foreground=TEXT,
                       rowheight=28, borderwidth=0, font=("Segoe UI", 11))
        stil.configure("Papatron.Treeview.Heading",
                       background=ROSU_INCHIS, foreground=TEXT,
                       font=("Segoe UI", 11, "bold"), borderwidth=0)
        stil.map("Papatron.Treeview",
                 background=[("selected", ROSU)],
                 foreground=[("selected", "#ffffff")])
        stil.map("Papatron.Treeview.Heading", background=[("active", ROSU)])

    def _buton(self, parinte, text, comanda, mare=False, **kw):
        kw.setdefault("fg_color", ROSU)
        kw.setdefault("hover_color", ROSU_HOVER)
        return ctk.CTkButton(
            parinte, text=text, command=comanda, text_color="#ffffff",
            font=("Segoe UI", 17 if mare else 13, "bold"),
            height=52 if mare else 34, corner_radius=10, **kw)

    # ---------------------------------------------------------------- header
    def _construieste_header(self):
        header = ctk.CTkFrame(self, fg_color=PANOU, corner_radius=0, height=110)
        header.pack(fill="x")
        header.pack_propagate(False)

        titlu = ctk.CTkFrame(header, fg_color="transparent")
        titlu.pack(side="left", padx=24, pady=10)
        ctk.CTkLabel(titlu, text="PAPATRON", font=("Impact", 38),
                     text_color=ROSU).pack(anchor="w")
        ctk.CTkLabel(titlu, text="OPTIMIZER", font=("Impact", 22),
                     text_color=TEXT).pack(anchor="w")

        self.bare = {}
        zona_bare = ctk.CTkFrame(header, fg_color="transparent")
        zona_bare.pack(side="right", padx=24, pady=14, fill="y")
        for cheie, eticheta in (("cpu", "CPU"), ("ram", "RAM"), ("disc", "DISC")):
            rand = ctk.CTkFrame(zona_bare, fg_color="transparent")
            rand.pack(fill="x", pady=2)
            ctk.CTkLabel(rand, text=eticheta, width=44, anchor="w",
                         font=("Segoe UI", 12, "bold"), text_color=TEXT_SLAB
                         ).pack(side="left")
            bara = ctk.CTkProgressBar(rand, width=260, height=14,
                                      progress_color=ROSU, fg_color=PANOU_2)
            bara.set(0)
            bara.pack(side="left", padx=8)
            valoare = ctk.CTkLabel(rand, text="0%", width=110, anchor="w",
                                   font=("Segoe UI", 12), text_color=TEXT)
            valoare.pack(side="left")
            self.bare[cheie] = (bara, valoare)

    # ---------------------------------------------------------------- taburi
    def _construieste_taburi(self):
        self.taburi = ctk.CTkTabview(
            self, fg_color=FUNDAL,
            segmented_button_fg_color=PANOU,
            segmented_button_selected_color=ROSU,
            segmented_button_selected_hover_color=ROSU_HOVER,
            segmented_button_unselected_color=PANOU,
            segmented_button_unselected_hover_color=PANOU_2,
            text_color=TEXT)
        self.taburi._segmented_button.configure(font=("Segoe UI", 14, "bold"), height=38)
        self.taburi.pack(fill="both", expand=True, padx=14, pady=(4, 14))
        self.taburi.add("  MONITOR  ")
        self.taburi.add("  OPTIMIZARE  ")
        self.taburi.add("  ANTIVIRUS  ")
        self._tab_monitor(self.taburi.tab("  MONITOR  "))
        self._tab_optimizare(self.taburi.tab("  OPTIMIZARE  "))
        self._tab_antivirus(self.taburi.tab("  ANTIVIRUS  "))

    # ------------------------------------------------------------ tab MONITOR
    def _tab_monitor(self, tab):
        sus = ctk.CTkFrame(tab, fg_color="transparent")
        sus.pack(fill="x", pady=(6, 8))
        ctk.CTkLabel(sus, text="Tot ce ruleaza acum pe calculator, sortat dupa consum:",
                     font=("Segoe UI", 13), text_color=TEXT_SLAB).pack(side="left", padx=4)
        self._buton(sus, "Inchide procesul selectat", self._inchide_selectat_monitor
                    ).pack(side="right", padx=4)

        cadru = ctk.CTkFrame(tab, fg_color=PANOU, corner_radius=10)
        cadru.pack(fill="both", expand=True)
        coloane = ("proces", "cpu", "ram", "stare")
        self.tabel = ttk.Treeview(cadru, columns=coloane, show="headings",
                                  style="Papatron.Treeview", selectmode="browse")
        self.tabel.heading("proces", text="Proces / Aplicatie")
        self.tabel.heading("cpu", text="CPU %")
        self.tabel.heading("ram", text="RAM (MB)")
        self.tabel.heading("stare", text="Consum")
        self.tabel.column("proces", width=420, anchor="w")
        self.tabel.column("cpu", width=110, anchor="center")
        self.tabel.column("ram", width=130, anchor="center")
        self.tabel.column("stare", width=160, anchor="center")
        scroll = ttk.Scrollbar(cadru, orient="vertical", command=self.tabel.yview)
        self.tabel.configure(yscrollcommand=scroll.set)
        self.tabel.pack(side="left", fill="both", expand=True, padx=(8, 0), pady=8)
        scroll.pack(side="right", fill="y", pady=8)
        self.tabel.tag_configure("mare", foreground=ROSU_HOVER)
        self.tabel.tag_configure("mediu", foreground=GALBEN)
        self.tabel.tag_configure("mic", foreground=TEXT_SLAB)
        self.tabel.tag_configure("protejat", foreground="#5a8dee")

        self.eticheta_total = ctk.CTkLabel(tab, text="", font=("Segoe UI", 12),
                                           text_color=TEXT_SLAB)
        self.eticheta_total.pack(anchor="w", padx=6, pady=(6, 0))

    def _refresh_periodic(self):
        stare = monitor.stare_sistem()
        for cheie, valoare, detaliu in (
            ("cpu", stare["cpu_procent"],
             f"{stare['cpu_procent']:.0f}%  ({stare['cpu_nuclee']} nuclee)"),
            ("ram", stare["ram_procent"],
             f"{stare['ram_procent']:.0f}%  ({stare['ram_folosit_gb']:.1f}/"
             f"{stare['ram_total_gb']:.1f} GB)"),
            ("disc", stare["disc_procent"], f"{stare['disc_procent']:.0f}%"),
        ):
            bara, eticheta = self.bare[cheie]
            bara.set(valoare / 100)
            bara.configure(progress_color=ROSU if valoare > 75 else
                           (GALBEN if valoare > 45 else VERDE))
            eticheta.configure(text=detaliu)

        selectat = self.tabel.selection()
        nume_selectat = self.tabel.item(selectat[0])["values"][0] if selectat else None
        self.tabel.delete(*self.tabel.get_children())
        procese = monitor.lista_procese()
        for p in procese[:120]:
            if p["protejat"]:
                tag, stare_text = "protejat", "sistem"
            elif p["cpu"] >= 10 or p["ram_mb"] >= 800:
                tag, stare_text = "mare", "MARE"
            elif p["cpu"] >= 2 or p["ram_mb"] >= 200:
                tag, stare_text = "mediu", "mediu"
            else:
                tag, stare_text = "mic", "mic"
            iid = self.tabel.insert("", "end", values=(
                p["nume"], f"{p['cpu']:.1f}", f"{p['ram_mb']:.0f}", stare_text),
                tags=(tag,))
            if p["nume"] == nume_selectat:
                self.tabel.selection_set(iid)
        self.eticheta_total.configure(
            text=f"Procese active: {stare['procese_total']}   |   "
                 "Albastru = proces de sistem (protejat)   "
                 "Rosu = consum mare   Galben = mediu")
        self.after(INTERVAL_REFRESH_MS, self._refresh_periodic)

    def _inchide_selectat_monitor(self):
        selectat = self.tabel.selection()
        if not selectat:
            messagebox.showinfo("PAPATRON", "Selecteaza mai intai un proces din lista.")
            return
        nume = self.tabel.item(selectat[0])["values"][0]
        if monitor.este_protejat(nume):
            messagebox.showwarning("PAPATRON", f"{nume} este proces critic de sistem "
                                   "si nu poate fi inchis.")
            return
        if not messagebox.askyesno("PAPATRON", f"Sigur inchizi {nume}?\n"
                                   "Datele nesalvate din aplicatie se pot pierde."):
            return
        pids = [p["pids"] for p in monitor.lista_procese() if p["nume"] == nume]
        mesaje = optimizer.inchide_procese(pids[0] if pids else [])
        if mesaje:
            messagebox.showinfo("PAPATRON", "\n".join(mesaje))

    # --------------------------------------------------------- tab OPTIMIZARE
    def _tab_optimizare(self, tab):
        ctk.CTkLabel(tab, text="1. Alege aplicatia / jocul pe care vrei sa-l folosesti."
                     "   2. Bifeaza ce vrei sa se inchida.   3. Apasa OPTIMIZEAZA!",
                     font=("Segoe UI", 13), text_color=TEXT_SLAB).pack(pady=(8, 4))

        mijloc = ctk.CTkFrame(tab, fg_color="transparent")
        mijloc.pack(fill="both", expand=True)
        mijloc.grid_columnconfigure((0, 1), weight=1, uniform="col")
        mijloc.grid_rowconfigure(0, weight=1)

        stanga = ctk.CTkFrame(mijloc, fg_color=PANOU, corner_radius=10)
        stanga.grid(row=0, column=0, sticky="nsew", padx=(0, 8), pady=4)
        ctk.CTkLabel(stanga, text="APLICATIA TA (joc, Chrome etc.)",
                     font=("Segoe UI", 14, "bold"), text_color=ROSU).pack(pady=(10, 2))
        self.lista_aplicatii = ctk.CTkScrollableFrame(stanga, fg_color=PANOU)
        self.lista_aplicatii.pack(fill="both", expand=True, padx=8, pady=8)

        dreapta = ctk.CTkFrame(mijloc, fg_color=PANOU, corner_radius=10)
        dreapta.grid(row=0, column=1, sticky="nsew", padx=(8, 0), pady=4)
        ctk.CTkLabel(dreapta, text="DE INCHIS (taburi si aplicatii inutile)",
                     font=("Segoe UI", 14, "bold"), text_color=ROSU).pack(pady=(10, 2))
        self.lista_inchidere = ctk.CTkScrollableFrame(dreapta, fg_color=PANOU)
        self.lista_inchidere.pack(fill="both", expand=True, padx=8, pady=8)

        jos = ctk.CTkFrame(tab, fg_color="transparent")
        jos.pack(fill="x", pady=8)
        self._buton(jos, "Reincarca listele", self._reincarca_aplicatii,
                    fg_color=PANOU_2, hover_color="#2c2c33").pack(side="left", padx=4)
        self._buton(jos, "Restaureaza setarile normale", self._restaureaza
                    ).pack(side="left", padx=4)
        self._buton(jos, "OPTIMIZEAZA!", self._optimizeaza, mare=True, width=300
                    ).pack(side="right", padx=4)

        self.jurnal_optimizare = ctk.CTkTextbox(tab, height=120, fg_color=PANOU,
                                                text_color=TEXT, font=("Consolas", 12))
        self.jurnal_optimizare.pack(fill="x", pady=(0, 4))
        self.jurnal_optimizare.insert("end", "Aici vezi ce face optimizarea...\n")
        self.jurnal_optimizare.configure(state="disabled")
        self._reincarca_aplicatii()

    def _scrie_jurnal(self, casuta, mesaje):
        casuta.configure(state="normal")
        for m in mesaje if isinstance(mesaje, list) else [mesaje]:
            casuta.insert("end", f"• {m}\n")
        casuta.see("end")
        casuta.configure(state="disabled")

    def _reincarca_aplicatii(self):
        for copil in self.lista_aplicatii.winfo_children():
            copil.destroy()
        for copil in self.lista_inchidere.winfo_children():
            copil.destroy()
        self.checkbox_inchidere.clear()
        self.aplicatii_curente.clear()

        aplicatii = monitor.aplicatii_cu_fereastra()
        if not aplicatii:
            ctk.CTkLabel(self.lista_aplicatii, text="Nu am gasit aplicatii deschise.",
                         text_color=TEXT_SLAB).pack(pady=10)
        for app in aplicatii:
            self.aplicatii_curente[app["nume"]] = app["pids"]
            text = f"{app['nume']}   ({app['ram_mb']:.0f} MB)"
            ctk.CTkRadioButton(self.lista_aplicatii, text=text,
                               variable=self.var_aplicatie_aleasa, value=app["nume"],
                               fg_color=ROSU, hover_color=ROSU_HOVER,
                               font=("Segoe UI", 13), text_color=TEXT
                               ).pack(anchor="w", pady=3, padx=4)
            cb = ctk.CTkCheckBox(self.lista_inchidere, text=text,
                                 fg_color=ROSU, hover_color=ROSU_HOVER,
                                 font=("Segoe UI", 13), text_color=TEXT)
            cb.pack(anchor="w", pady=3, padx=4)
            self.checkbox_inchidere[app["nume"]] = (cb, app["pids"])

    def _optimizeaza(self):
        aleasa = self.var_aplicatie_aleasa.get()
        if not aleasa or aleasa not in self.aplicatii_curente:
            messagebox.showinfo("PAPATRON", "Alege mai intai aplicatia pe care vrei "
                                "sa o folosesti (coloana din stanga).")
            return
        pids_aplicatie = self.aplicatii_curente[aleasa]
        pids_de_inchis = []
        nume_de_inchis = []
        for nume, (cb, pids) in self.checkbox_inchidere.items():
            if cb.get() and nume != aleasa:
                pids_de_inchis += pids
                nume_de_inchis.append(nume)
        if nume_de_inchis and not messagebox.askyesno(
                "PAPATRON", "Se vor inchide: " + ", ".join(nume_de_inchis) +
                "\nDatele nesalvate se pot pierde. Continui?"):
            return
        self._scrie_jurnal(self.jurnal_optimizare, f"=== OPTIMIZARE pentru {aleasa} ===")
        mesaje = optimizer.optimizeaza_pentru(pids_aplicatie, pids_de_inchis)
        self.pids_optimizate = pids_aplicatie
        self._scrie_jurnal(self.jurnal_optimizare, mesaje)
        self._reincarca_aplicatii()

    def _restaureaza(self):
        mesaje = optimizer.reseteaza_prioritate(self.pids_optimizate)
        mesaje.append(optimizer.seteaza_plan_alimentare(performanta=False))
        self.pids_optimizate = []
        self._scrie_jurnal(self.jurnal_optimizare, ["=== RESTAURARE ==="] + mesaje)

    # ---------------------------------------------------------- tab ANTIVIRUS
    def _tab_antivirus(self, tab):
        sus = ctk.CTkFrame(tab, fg_color=PANOU, corner_radius=10)
        sus.pack(fill="x", pady=(8, 6))
        self.eticheta_defender = ctk.CTkLabel(
            sus, text="Stare protectie: se verifica...",
            font=("Segoe UI", 13, "bold"), text_color=TEXT_SLAB)
        self.eticheta_defender.pack(side="left", padx=14, pady=10)

        butoane = ctk.CTkFrame(tab, fg_color="transparent")
        butoane.pack(fill="x", pady=4)
        self.buton_scan_rapid = self._buton(butoane, "SCANARE RAPIDA",
                                            lambda: self._porneste_scanare(rapida=True))
        self.buton_scan_rapid.pack(side="left", padx=4)
        self.buton_scan_complet = self._buton(butoane, "Scanare completa",
                                              lambda: self._porneste_scanare(rapida=False),
                                              fg_color=PANOU_2, hover_color="#2c2c33")
        self.buton_scan_complet.pack(side="left", padx=4)
        self._buton(butoane, "Cauta keyloggere (euristic)", self._cauta_keyloggere,
                    fg_color=PANOU_2, hover_color="#2c2c33").pack(side="left", padx=4)
        self._buton(butoane, "Actualizeaza semnaturile",
                    lambda: self._ruleaza_in_fundal(antivirus.actualizeaza_semnaturi,
                                                    "Actualizez semnaturile..."),
                    fg_color=PANOU_2, hover_color="#2c2c33").pack(side="left", padx=4)
        self._buton(butoane, "STERGE TOTI VIRUSII GASITI", self._sterge_amenintari
                    ).pack(side="right", padx=4)

        self.jurnal_antivirus = ctk.CTkTextbox(tab, fg_color=PANOU, text_color=TEXT,
                                               font=("Consolas", 12))
        self.jurnal_antivirus.pack(fill="both", expand=True, pady=6)
        self._scrie_jurnal(self.jurnal_antivirus, [
            "PAPATRON foloseste motorul real Windows Defender pentru scanare si stergere.",
            "Apasa SCANARE RAPIDA pentru a verifica calculatorul de virusi si keyloggere.",
            "Pentru stergerea virusilor porneste aplicatia ca Administrator.",
        ])
        threading.Thread(target=self._verifica_defender, daemon=True).start()

    def _verifica_defender(self):
        stare = antivirus.stare_defender()
        if stare.get("disponibil"):
            text = ("Stare protectie: Windows Defender ACTIV"
                    if stare.get("antivirus_activ") else
                    "Stare protectie: Defender OPRIT — alt antivirus instalat?")
            culoare = VERDE if stare.get("antivirus_activ") else GALBEN
        else:
            text = f"Stare protectie: {stare.get('mesaj', 'necunoscuta')}"
            culoare = GALBEN
        self.after(0, lambda: self.eticheta_defender.configure(text=text, text_color=culoare))

    def _ruleaza_in_fundal(self, functie, mesaj_start):
        self._scrie_jurnal(self.jurnal_antivirus, mesaj_start)

        def lucru():
            ok, mesaj = functie()
            self.after(0, lambda: self._scrie_jurnal(
                self.jurnal_antivirus, mesaj if ok else f"EROARE: {mesaj}"))
        threading.Thread(target=lucru, daemon=True).start()

    def _porneste_scanare(self, rapida: bool):
        if self.scanare_in_curs:
            messagebox.showinfo("PAPATRON", "O scanare este deja in curs.")
            return
        self.scanare_in_curs = True
        self.buton_scan_rapid.configure(state="disabled")
        self.buton_scan_complet.configure(state="disabled")
        tip = "rapida (cateva minute)" if rapida else "completa (poate dura ore)"
        self._scrie_jurnal(self.jurnal_antivirus, f"Scanare {tip} pornita...")

        def lucru():
            ok, mesaj = antivirus.scanare(rapida=rapida)
            amenintari, eroare = antivirus.lista_amenintari()
            linii = [mesaj if ok else f"EROARE: {mesaj}"]
            if eroare:
                linii.append(f"EROARE la citirea amenintarilor: {eroare}")
            elif not amenintari:
                linii.append("FELICITARI! Nicio amenintare gasita — calculatorul e curat.")
            else:
                linii.append(f"ATENTIE: {len(amenintari)} amenintari gasite:")
                for t in amenintari:
                    stare = "ACTIVA" if t["activ"] else "in carantina/istoric"
                    linii.append(f"  [{t['severitate']}] {t['nume']} ({stare})")
                    for f in t["fisiere"]:
                        linii.append(f"      fisier: {f}")
                linii.append("Apasa STERGE TOTI VIRUSII GASITI pentru a scapa de ei.")

            def termina():
                self.scanare_in_curs = False
                self.buton_scan_rapid.configure(state="normal")
                self.buton_scan_complet.configure(state="normal")
                self._scrie_jurnal(self.jurnal_antivirus, linii)
            self.after(0, termina)
        threading.Thread(target=lucru, daemon=True).start()

    def _sterge_amenintari(self):
        if not messagebox.askyesno("PAPATRON", "Windows Defender va elimina toate "
                                   "amenintarile active gasite. Continui?"):
            return
        self._ruleaza_in_fundal(antivirus.sterge_amenintare, "Sterg amenintarile...")

    def _cauta_keyloggere(self):
        self._scrie_jurnal(self.jurnal_antivirus,
                           "Caut procese suspecte de tip keylogger/spyware...")

        def lucru():
            suspecte = antivirus.cauta_procese_suspecte()
            if not suspecte:
                linii = ["Niciun proces suspect de keylogger gasit. Arata bine!"]
            else:
                linii = [f"{len(suspecte)} procese SUSPECTE gasite "
                         "(nu e sigur ca sunt virusi — verifica-le):"]
                for s in suspecte:
                    linii.append(f"  PID {s['pid']}: {s['nume']} — {', '.join(s['motive'])}")
                    linii.append(f"      locatie: {s['exe']}")
                linii.append("Recomandare: ruleaza SCANARE RAPIDA ca Defender sa le verifice.")
            self.after(0, lambda: self._scrie_jurnal(self.jurnal_antivirus, linii))
        threading.Thread(target=lucru, daemon=True).start()


def main():
    if os.name != "nt":
        print("Atentie: PAPATRON OPTIMIZER este facut pentru Windows. "
              "Unele functii (antivirus, plan de alimentare) nu merg pe alt sistem.")
    app = PapatronOptimizer()
    app.mainloop()


if __name__ == "__main__":
    main()
