"""Antivirus: comanda motorul Windows Defender (scanare, amenintari, stergere)
si detecteaza euristic procese suspecte de tip keylogger/spyware.

Nota: detectia si stergerea reala a virusilor o face motorul Microsoft Defender,
care e deja in Windows — aplicatia il controleaza si iti arata rezultatele simplu.
"""

import json
import os
import subprocess

import psutil

EUSTE_WINDOWS = os.name == "nt"

# Tipare de nume intalnite des la keyloggere / spyware.
TIPARE_SUSPECTE = ("keylog", "keyhook", "klog", "spyware", "spy_", "_spy",
                   "stealer", "rat.exe", "njrat", "darkcomet", "remcos",
                   "agenttesla", "hawkeye", "snakekeylogger")

# Locuri din care aplicatiile legitime nu ruleaza de obicei.
LOCATII_SUSPECTE = ("\\appdata\\local\\temp\\", "\\windows\\temp\\",
                    "\\users\\public\\", "\\programdata\\temp\\",
                    "\\appdata\\roaming\\microsoft\\windows\\start menu\\")


def _powershell(comanda: str, timeout: int = 900) -> tuple[bool, str]:
    """Ruleaza o comanda PowerShell si intoarce (succes, iesire)."""
    if not EUSTE_WINDOWS:
        return False, "Functiile antivirus sunt disponibile doar pe Windows."
    try:
        rezultat = subprocess.run(
            ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", comanda],
            capture_output=True, text=True, timeout=timeout,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        iesire = (rezultat.stdout or "").strip()
        if rezultat.returncode != 0:
            return False, (rezultat.stderr or iesire or "Comanda a esuat").strip()
        return True, iesire
    except subprocess.TimeoutExpired:
        return False, "Comanda a durat prea mult si a fost oprita."
    except FileNotFoundError:
        return False, "PowerShell nu a fost gasit."


def stare_defender() -> dict:
    """Starea motorului Microsoft Defender."""
    ok, iesire = _powershell(
        "Get-MpComputerStatus | Select-Object AntivirusEnabled,RealTimeProtectionEnabled,"
        "AntivirusSignatureLastUpdated,QuickScanEndTime | ConvertTo-Json", timeout=60)
    if not ok:
        return {"disponibil": False, "mesaj": iesire}
    try:
        date = json.loads(iesire)
        return {
            "disponibil": True,
            "antivirus_activ": bool(date.get("AntivirusEnabled")),
            "protectie_timp_real": bool(date.get("RealTimeProtectionEnabled")),
        }
    except (json.JSONDecodeError, TypeError):
        return {"disponibil": False, "mesaj": "Nu am putut citi starea Defender."}


def scanare(rapida: bool = True, cale: str | None = None) -> tuple[bool, str]:
    """Porneste o scanare Defender. Blocheaza pana se termina (ruleaza in thread)."""
    if cale:
        comanda = f"Start-MpScan -ScanType CustomScan -ScanPath '{cale}'"
    else:
        tip = "QuickScan" if rapida else "FullScan"
        comanda = f"Start-MpScan -ScanType {tip}"
    ok, iesire = _powershell(comanda, timeout=3600 if not rapida else 1200)
    if ok:
        return True, "Scanare terminata."
    return False, iesire


def lista_amenintari() -> tuple[list[dict], str]:
    """Amenintarile detectate de Defender (active si din istoric)."""
    ok, iesire = _powershell(
        "Get-MpThreat | Select-Object ThreatID,ThreatName,SeverityID,Resources,IsActive"
        " | ConvertTo-Json -Depth 3", timeout=120)
    if not ok:
        return [], iesire
    if not iesire:
        return [], ""
    try:
        date = json.loads(iesire)
        if isinstance(date, dict):
            date = [date]
        severitati = {0: "Necunoscuta", 1: "Scazuta", 2: "Moderata", 4: "Ridicata", 5: "SEVERA"}
        amenintari = []
        for t in date:
            resurse = t.get("Resources") or []
            if isinstance(resurse, str):
                resurse = [resurse]
            amenintari.append({
                "id": t.get("ThreatID"),
                "nume": t.get("ThreatName", "Necunoscut"),
                "severitate": severitati.get(t.get("SeverityID", 0), "Necunoscuta"),
                "fisiere": [str(r) for r in resurse][:5],
                "activ": bool(t.get("IsActive")),
            })
        return amenintari, ""
    except json.JSONDecodeError:
        return [], "Nu am putut citi lista de amenintari."


def sterge_amenintare(threat_id: int | None = None) -> tuple[bool, str]:
    """Sterge amenintarile active prin Defender (necesita Administrator)."""
    if threat_id is not None:
        comanda = f"Remove-MpThreat -ThreatID {threat_id}"
    else:
        comanda = "Remove-MpThreat"
    ok, iesire = _powershell(comanda, timeout=300)
    if ok:
        return True, "Amenintare eliminata de Windows Defender."
    return False, iesire or "Stergerea a esuat — porneste aplicatia ca Administrator."


def actualizeaza_semnaturi() -> tuple[bool, str]:
    ok, iesire = _powershell("Update-MpSignature", timeout=600)
    return (True, "Semnaturi de virusi actualizate.") if ok else (False, iesire)


def cauta_procese_suspecte() -> list[dict]:
    """Euristica anti-keylogger: procese cu nume suspecte sau care ruleaza
    din locatii folosite de malware. NU sunt sigur virusi — sunt suspecti
    pe care ii poti scana cu Defender direct din aplicatie."""
    suspecte = []
    for proc in psutil.process_iter(attrs=["pid", "name", "exe"]):
        nume = (proc.info.get("name") or "").lower()
        exe = (proc.info.get("exe") or "").lower()
        motive = []
        for tipar in TIPARE_SUSPECTE:
            if tipar in nume or tipar in exe:
                motive.append(f"nume suspect (contine '{tipar}')")
                break
        for locatie in LOCATII_SUSPECTE:
            if exe and locatie in exe:
                motive.append("ruleaza dintr-o locatie folosita des de malware")
                break
        if motive:
            suspecte.append({
                "pid": proc.info["pid"],
                "nume": proc.info.get("name") or "?",
                "exe": proc.info.get("exe") or "necunoscut",
                "motive": motive,
            })
    return suspecte
