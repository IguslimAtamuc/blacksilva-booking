"""Monitorizare sistem: CPU, RAM, disc, retea si lista de procese (cu psutil)."""

import os
import time

import psutil

# Procese critice de Windows care NU trebuie atinse niciodata.
PROCESE_PROTEJATE = {
    "system", "system idle process", "registry", "smss.exe", "csrss.exe",
    "wininit.exe", "winlogon.exe", "services.exe", "lsass.exe", "svchost.exe",
    "fontdrvhost.exe", "dwm.exe", "explorer.exe", "audiodg.exe", "conhost.exe",
    "sihost.exe", "ctfmon.exe", "taskhostw.exe", "runtimebroker.exe",
    "searchindexer.exe", "spoolsv.exe", "msmpeng.exe", "nissrv.exe",
    "securityhealthservice.exe", "wmiprvse.exe", "dllhost.exe", "memcompression",
    "startmenuexperiencehost.exe", "shellexperiencehost.exe", "textinputhost.exe",
    "applicationframehost.exe", "python.exe", "pythonw.exe", "py.exe",
}

# Nume de procese cunoscute ca jocuri / aplicatii grele (pentru sugestii).
EXTENSII_JOC_HINT = ("steam", "epicgames", "riot", "battle.net", "origin",
                     "gog", "launcher", "game")


def este_protejat(nume_proces: str) -> bool:
    return (nume_proces or "").lower() in PROCESE_PROTEJATE


def stare_sistem() -> dict:
    """Citeste sarcina globala a calculatorului."""
    ram = psutil.virtual_memory()
    try:
        disc = psutil.disk_usage(os.path.abspath(os.sep))
    except OSError:
        disc = None
    freq = None
    try:
        f = psutil.cpu_freq()
        if f:
            freq = f.current
    except Exception:
        pass
    return {
        "cpu_procent": psutil.cpu_percent(interval=None),
        "cpu_nuclee": psutil.cpu_count(logical=True),
        "cpu_frecventa_mhz": freq,
        "ram_procent": ram.percent,
        "ram_folosit_gb": (ram.total - ram.available) / (1024 ** 3),
        "ram_total_gb": ram.total / (1024 ** 3),
        "disc_procent": disc.percent if disc else 0.0,
        "procese_total": len(psutil.pids()),
    }


def lista_procese(minim_ram_mb: float = 1.0) -> list[dict]:
    """Lista proceselor, grupate dupa nume, sortate dupa consum.

    cpu_percent() pe psutil masoara diferenta fata de apelul anterior,
    asa ca valorile devin corecte incepand cu a doua citire.
    """
    grupuri: dict[str, dict] = {}
    atribute = ["pid", "name", "exe", "username", "memory_info", "cpu_percent"]
    for proc in psutil.process_iter(attrs=atribute):
        info = proc.info
        nume = info.get("name") or f"pid-{info['pid']}"
        mem = info.get("memory_info")
        ram_mb = (mem.rss / (1024 ** 2)) if mem else 0.0
        cpu = info.get("cpu_percent") or 0.0
        g = grupuri.setdefault(nume, {
            "nume": nume,
            "pids": [],
            "cpu": 0.0,
            "ram_mb": 0.0,
            "exe": info.get("exe") or "",
            "protejat": este_protejat(nume),
        })
        g["pids"].append(info["pid"])
        g["cpu"] += cpu
        g["ram_mb"] += ram_mb
        if not g["exe"] and info.get("exe"):
            g["exe"] = info["exe"]

    nr_nuclee = psutil.cpu_count(logical=True) or 1
    rezultat = []
    for g in grupuri.values():
        # normalizeaza CPU la 100% total (psutil raporteaza per-nucleu)
        g["cpu"] = min(g["cpu"] / nr_nuclee, 100.0)
        if g["ram_mb"] >= minim_ram_mb:
            rezultat.append(g)
    rezultat.sort(key=lambda x: (x["cpu"], x["ram_mb"]), reverse=True)
    return rezultat


def aplicatii_cu_fereastra() -> list[dict]:
    """Aplicatiile pornite de utilizator (candidate pentru optimizare).

    Pe Windows filtram dupa procesele care au fereastra vizibila; daca
    API-ul nu e disponibil, intoarcem procesele ne-protejate cu RAM > 30MB.
    """
    nume_cu_fereastra = _nume_procese_cu_fereastra_windows()
    procese = lista_procese(minim_ram_mb=15.0)
    rezultat = []
    for p in procese:
        if p["protejat"]:
            continue
        if nume_cu_fereastra is not None:
            if p["nume"].lower() in nume_cu_fereastra:
                rezultat.append(p)
        elif p["ram_mb"] > 30.0:
            rezultat.append(p)
    return rezultat


def _nume_procese_cu_fereastra_windows():
    """Numele proceselor care au cel putin o fereastra vizibila (doar Windows)."""
    if os.name != "nt":
        return None
    try:
        import ctypes
        from ctypes import wintypes

        user32 = ctypes.windll.user32
        pids_cu_fereastra: set[int] = set()

        @ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
        def enum_callback(hwnd, _lparam):
            if user32.IsWindowVisible(hwnd) and user32.GetWindowTextLengthW(hwnd) > 0:
                pid = wintypes.DWORD()
                user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                pids_cu_fereastra.add(pid.value)
            return True

        user32.EnumWindows(enum_callback, 0)

        nume: set[str] = set()
        for pid in pids_cu_fereastra:
            try:
                nume.add(psutil.Process(pid).name().lower())
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        return nume
    except Exception:
        return None
