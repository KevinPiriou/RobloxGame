#!/usr/bin/env python3
from __future__ import annotations
import argparse
import json
import threading
import traceback
import webbrowser
from pathlib import Path

from meta_lab.catalog import catalog_support_report, load_catalog, validate_catalog
from meta_lab.analyzer import run_analysis
from meta_lab.engine import draft_build, analytical_evaluate, event_simulate
from meta_lab.evidence import inspect_source_snapshot, require_current_sources

ROOT=Path(__file__).resolve().parent
DEFAULT_CATALOG=ROOT/"catalogs"/"current_project.json"

def launch_gui():
    import tkinter as tk
    from tkinter import ttk,filedialog,messagebox

    win=tk.Tk()
    win.title("Meta Build Lab")
    win.geometry("820x650")
    win.minsize(760,580)

    variables={
        "catalog":tk.StringVar(value=str(DEFAULT_CATALOG)),
        "output":tk.StringVar(value=str((ROOT/"meta_results").resolve())),
        "candidates":tk.StringVar(value="600"),
        "top":tk.StringVar(value="40"),
        "reps":tk.StringVar(value="8"),
        "seed":tk.StringVar(value="1337"),
    }

    frame=ttk.Frame(win,padding=18)
    frame.pack(fill="both",expand=True)
    ttk.Label(
        frame,
        text="Meta Build Lab",
        font=("Segoe UI",21,"bold")
    ).grid(row=0,column=0,columnspan=3,sticky="w")
    ttk.Label(
        frame,
        text=(
            "Analyse les perks, objets, armes et synergies, puis confirme "
            "les meilleurs builds par simulation événementielle."
        ),
        wraplength=750
    ).grid(row=1,column=0,columnspan=3,sticky="w",pady=(4,16))

    def browse_catalog():
        path=filedialog.askopenfilename(
            filetypes=[("Catalogue JSON","*.json")],
            initialdir=str(ROOT/"catalogs")
        )
        if path:
            variables["catalog"].set(path)

    def browse_output():
        path=filedialog.askdirectory(
            initialdir=variables["output"].get()
        )
        if path:
            variables["output"].set(path)

    fields=[
        ("Catalogue","catalog",browse_catalog),
        ("Dossier de sortie","output",browse_output),
        ("Candidats analytiques","candidates",None),
        ("Builds confirmés","top",None),
        ("Répétitions événementielles","reps",None),
        ("Seed","seed",None),
    ]
    for row,(label,key,command) in enumerate(fields,start=2):
        ttk.Label(frame,text=label).grid(
            row=row,column=0,sticky="w",pady=5
        )
        ttk.Entry(
            frame,
            textvariable=variables[key],
            width=58 if row<4 else 20
        ).grid(row=row,column=1,sticky="we",pady=5)
        if command:
            ttk.Button(
                frame,text="Choisir",command=command
            ).grid(row=row,column=2,padx=6)

    profile_variables={}
    ttk.Label(frame,text="Profils").grid(
        row=8,column=0,sticky="nw",pady=5
    )
    profile_frame=ttk.Frame(frame)
    profile_frame.grid(row=8,column=1,sticky="w")
    for profile_id,label in [
        ("beginner","Débutant"),
        ("medium","Moyen"),
        ("experienced","Expérimenté")
    ]:
        value=tk.BooleanVar(value=True)
        profile_variables[profile_id]=value
        ttk.Checkbutton(
            profile_frame,text=label,variable=value
        ).pack(side="left",padx=4)

    progress=ttk.Progressbar(frame,mode="indeterminate")
    progress.grid(
        row=9,column=0,columnspan=3,
        sticky="we",pady=(18,4)
    )
    log=tk.Text(frame,height=13)
    log.grid(row=10,column=0,columnspan=3,sticky="nsew")
    frame.columnconfigure(1,weight=1)
    frame.rowconfigure(10,weight=1)

    def append(message):
        log.insert("end",str(message)+"\n")
        log.see("end")

    def worker():
        try:
            catalog=load_catalog(Path(variables["catalog"].get()))
            source_evidence=require_current_sources(
                catalog, Path(variables["catalog"].get())
            )
            profiles=[
                profile_id
                for profile_id,value in profile_variables.items()
                if value.get()
            ]
            if not profiles:
                raise ValueError("Sélectionne au moins un profil.")
            result=run_analysis(
                catalog,
                Path(variables["output"].get()),
                int(variables["candidates"].get()),
                int(variables["top"].get()),
                int(variables["reps"].get()),
                int(variables["seed"].get()),
                profiles,
                lambda message:win.after(0,append,message),
                {
                    "source_snapshot": source_evidence,
                    "model_support": catalog_support_report(catalog),
                },
            )
            win.after(
                0,append,
                json.dumps(result,ensure_ascii=False,indent=2)
            )
            win.after(0,progress.stop)
            win.after(
                0,
                lambda:webbrowser.open(
                    Path(result["report"]).resolve().as_uri()
                )
            )
            win.after(
                0,
                lambda:messagebox.showinfo(
                    "Terminé",
                    f"Rapport :\n{result['report']}"
                )
            )
        except Exception:
            error=traceback.format_exc()
            win.after(0,append,error)
            win.after(0,progress.stop)
            win.after(
                0,
                lambda:messagebox.showerror("Erreur",error)
            )

    def start():
        log.delete("1.0","end")
        progress.start(10)
        threading.Thread(target=worker,daemon=True).start()

    def validate_current():
        try:
            catalog=load_catalog(Path(variables["catalog"].get()))
            validate_catalog(catalog)
            source=inspect_source_snapshot(
                catalog, Path(variables["catalog"].get())
            )
            messagebox.showinfo(
                "Catalogue",
                "Catalogue structurellement valide.\n"
                f"Sources courantes : {'oui' if source['ok'] else 'non'}."
            )
        except Exception:
            messagebox.showerror("Erreur",traceback.format_exc())

    buttons=ttk.Frame(frame)
    buttons.grid(
        row=11,column=0,columnspan=3,
        sticky="w",pady=12
    )
    ttk.Button(
        buttons,
        text="Lancer l'analyse de méta",
        command=start
    ).pack(side="left")
    ttk.Button(
        buttons,
        text="Valider le catalogue",
        command=validate_current
    ).pack(side="left",padx=8)

    win.mainloop()

def create_parser():
    parser=argparse.ArgumentParser(
        description="Laboratoire de méta combinatoire pour RobloxGame."
    )
    parser.add_argument(
        "--catalog",
        type=Path,
        default=DEFAULT_CATALOG
    )
    sub=parser.add_subparsers(dest="command",required=True)

    analyze=sub.add_parser("analyze")
    analyze.add_argument(
        "--output",
        type=Path,
        default=ROOT/"meta_results"
    )
    analyze.add_argument("--candidates",type=int,default=600)
    analyze.add_argument("--top-event",type=int,default=40)
    analyze.add_argument("--repetitions",type=int,default=8)
    analyze.add_argument("--seed",type=int,default=1337)
    analyze.add_argument(
        "--allow-partial-coverage",
        action="store_true",
        help=(
            "Autorise une analyse de diagnostic qui ne couvre pas tout le "
            "catalogue. Ses resultats ne constituent pas une preuve."
        ),
    )
    analyze.add_argument(
        "--profiles",
        nargs="+",
        default=["beginner","medium","experienced"]
    )

    sub.add_parser("validate")
    sub.add_parser("doctor")

    importer=sub.add_parser("import-roblox")
    importer.add_argument("--export",type=Path,required=True)
    importer.add_argument("--output",type=Path,required=True)

    single=sub.add_parser("single")
    single.add_argument("--profile",default="medium")
    single.add_argument(
        "--scenario",
        default="project_horde_12m"
    )
    single.add_argument("--seed",type=int,default=42)

    sub.add_parser("gui")
    return parser

def main():
    args=create_parser().parse_args()
    catalog=load_catalog(args.catalog)

    if args.command=="gui":
        launch_gui()
        return 0

    if args.command=="validate":
        print(json.dumps(catalog_support_report(catalog),ensure_ascii=False,indent=2))
        print("Catalogue structurellement valide.")
        return 0

    if args.command=="doctor":
        report={
            "source_snapshot":inspect_source_snapshot(catalog,args.catalog),
            "model_support":catalog_support_report(catalog),
        }
        print(json.dumps(report,ensure_ascii=False,indent=2))
        if not report["source_snapshot"]["ok"]:
            return 2
        return 0

    if args.command=="import-roblox":
        from meta_lab.roblox_adapter import import_file
        import_file(args.catalog,args.export,args.output)
        print(f"Catalogue importé : {args.output}")
        return 0

    if args.command=="analyze":
        source_evidence=require_current_sources(catalog,args.catalog)
        result=run_analysis(
            catalog,
            args.output,
            args.candidates,
            args.top_event,
            args.repetitions,
            args.seed,
            args.profiles,
            print,
            {
                "source_snapshot":source_evidence,
                "model_support":catalog_support_report(catalog),
            },
            require_complete_coverage=not args.allow_partial_coverage,
        )
        print(json.dumps(result,ensure_ascii=False,indent=2))
        return 0

    if args.command=="single":
        require_current_sources(catalog,args.catalog)
        build=draft_build(
            catalog,args.profile,args.seed,1
        )
        scenario=next(
            scenario
            for scenario in catalog["run_scenarios"]
            if scenario["id"]==args.scenario
        )
        event=event_simulate(
            catalog,build,args.profile,scenario,args.seed,True
        )
        print(json.dumps({
            "signature":build.signature(),
            "analytical":analytical_evaluate(
                catalog,build,args.profile
            ),
            "event":event.__dict__
        },ensure_ascii=False,indent=2))
        return 0

    return 1

if __name__=="__main__":
    raise SystemExit(main())
