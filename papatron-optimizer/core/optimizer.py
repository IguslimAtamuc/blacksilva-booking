"""Optimizare: prioritate pentru aplicatia aleasa, inchidere aplicatii de fundal,
plan de alimentare High Performance si eliberare RAM."""

import os
import subprocess

import psutil

from .monitor import este_protejat

PLAN_HIGH_PERFORMANCE = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
PLAN_BALANCED = "381b4222-f694-41f0-9685-ff5bb260df2e"

EUSTE_WINDOWS = os.name == "nt"


def _flags_fara_fereastra():
    if EUSTE_WINDOWS:
        return {"creationflags": subprocess.CREATE_NO_WINDOW}
    return {}


def seteaza_prioritate_mare(pids: list[int]) -> list[str]:
    """Pune procesul ales pe prioritate HIGH ca sa primeasca CPU cu prioritate."""
    mesaje = []
    for pid in pids:
        try:
            p = psutil.Process(pid)
            if EUSTE_WINDOWS:
                p.nice(psutil.HIGH_PRIORITY_CLASS)
            else:
                p.nice(-10)
            mesaje.append(f"Prioritate MARE setata pentru {p.name()} (PID {pid})")
        except psutil.AccessDenied:
            mesaje.append(f"Acces refuzat la PID {pid} — porneste aplicatia ca Administrator")
        except psutil.NoSuchProcess:
            pass
    return mesaje


def reseteaza_prioritate(pids: list[int]) -> list[str]:
    mesaje = []
    for pid in pids:
        try:
            p = psutil.Process(pid)
            p.nice(psutil.NORMAL_PRIORITY_CLASS if EUSTE_WINDOWS else 0)
            mesaje.append(f"Prioritate normala pentru {p.name()} (PID {pid})")
        except (psutil.AccessDenied, psutil.NoSuchProcess):
            pass
    return mesaje


def inchide_procese(pids: list[int]) -> list[str]:
    """Inchide procesele alese de utilizator. Refuza procesele critice Windows."""
    mesaje = []
    procese = []
    for pid in pids:
        try:
            p = psutil.Process(pid)
            if este_protejat(p.name()):
                mesaje.append(f"REFUZAT: {p.name()} este proces critic de sistem")
                continue
            nume = p.name()
            p.terminate()
            procese.append((p, nume))
        except psutil.NoSuchProcess:
            pass
        except psutil.AccessDenied:
            mesaje.append(f"Acces refuzat la PID {pid}")
    _, vii = psutil.wait_procs([p for p, _ in procese], timeout=3)
    for p in vii:
        try:
            p.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    for _, nume in procese:
        mesaje.append(f"Inchis: {nume}")
    return mesaje


def seteaza_plan_alimentare(performanta: bool) -> str:
    """Activeaza planul High Performance (sau revine la Balanced)."""
    if not EUSTE_WINDOWS:
        return "Planul de alimentare se poate schimba doar pe Windows."
    ghid = PLAN_HIGH_PERFORMANCE if performanta else PLAN_BALANCED
    try:
        rezultat = subprocess.run(
            ["powercfg", "/setactive", ghid],
            capture_output=True, text=True, timeout=15, **_flags_fara_fereastra(),
        )
        if rezultat.returncode == 0:
            return ("Plan de alimentare: HIGH PERFORMANCE activat"
                    if performanta else "Plan de alimentare: Balanced restaurat")
        return f"powercfg a esuat: {rezultat.stderr.strip() or rezultat.stdout.strip()}"
    except Exception as e:
        return f"Nu am putut schimba planul de alimentare: {e}"


def elibereaza_ram(pids_pastrate: list[int]) -> str:
    """Cere Windows-ului sa goleasca working-set-ul proceselor de fundal,
    eliberand RAM pentru aplicatia aleasa. Nu inchide nimic."""
    if not EUSTE_WINDOWS:
        return "Eliberarea RAM functioneaza doar pe Windows."
    import ctypes

    psapi = ctypes.windll.psapi
    kernel32 = ctypes.windll.kernel32
    PROCESS_SET_QUOTA = 0x0100
    PROCESS_QUERY_INFORMATION = 0x0400

    eliberate = 0
    pastrate = set(pids_pastrate)
    pid_propriu = os.getpid()
    for proc in psutil.process_iter(attrs=["pid", "name"]):
        pid = proc.info["pid"]
        if pid in pastrate or pid == pid_propriu or este_protejat(proc.info["name"]):
            continue
        handle = kernel32.OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_INFORMATION, False, pid)
        if handle:
            if psapi.EmptyWorkingSet(handle):
                eliberate += 1
            kernel32.CloseHandle(handle)
    return f"RAM eliberat din {eliberate} procese de fundal"


def optimizeaza_pentru(pids_aplicatie: list[int], pids_de_inchis: list[int]) -> list[str]:
    """Pachetul complet de optimizare pentru aplicatia aleasa."""
    mesaje = []
    if pids_de_inchis:
        mesaje += inchide_procese(pids_de_inchis)
    mesaje += seteaza_prioritate_mare(pids_aplicatie)
    mesaje.append(seteaza_plan_alimentare(performanta=True))
    mesaje.append(elibereaza_ram(pids_pastrate=pids_aplicatie))
    mesaje.append("OPTIMIZARE COMPLETA! Resursele sunt concentrate pe aplicatia ta.")
    return mesaje
