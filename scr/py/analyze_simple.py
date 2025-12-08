#!/usr/bin/env python3
import sys, os, glob, argparse
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

def find_latest_csv():
    cand = sorted(glob.glob("bench_results_*.csv"), key=os.path.getmtime)
    return cand[-1] if cand else None

def load(path):
    df = pd.read_csv(path)
    need = ["program","impl","N","workers","unit","run_idx","time_s"]
    miss = [c for c in need if c not in df.columns]
    if miss: raise ValueError(f"Missing columns: {miss}")
    df["N"] = df["N"].astype(int)
    df["workers"] = df["workers"].astype(int)
    df["run_idx"] = df["run_idx"].astype(int)
    df["time_s"] = df["time_s"].astype(float)
    return df

def aggregate(df):
    return (df.groupby(["impl","program","N","workers","unit"], as_index=False)
              .agg(time_s_median=("time_s","median"),
                   time_s_mean=("time_s","mean"),
                   time_s_min=("time_s","min"),
                   time_s_max=("time_s","max")))

def pick_best_N(agg):
    # Берём самый большой N, где есть >=2 реализации (чтобы график был сравнимым)
    candidates = []
    for n, dn in agg.groupby("N"):
        impls = dn["impl"].nunique()
        candidates.append((n, impls))
    # сортируем по N убыв.
    candidates.sort(key=lambda x: x[0], reverse=True)
    for n, impls in candidates:
        if impls >= 2:
            return n
    # иначе просто максимум
    return agg["N"].max()

def print_table(title, df):
    print("="*len(title))
    print(title)
    print("="*len(title))
    if df.empty:
        print("(no data)")
    else:
        print(df.to_string())
    print()

def compute_speedup(subset):
    # baseline: workers==1 если есть, иначе минимальный workers для каждой impl
    base = (subset.sort_values("workers")
                  .groupby("impl", as_index=True)
                  .first()["time_s_median"]
                  .rename("Tbase"))
    out = subset.merge(base, on="impl", how="left")
    out["speedup"] = out["Tbase"] / out["time_s_median"]
    out["baseline_workers"] = (subset.groupby("impl")["workers"].min())
    out["baseline_workers"] = out["baseline_workers"].reindex(out["impl"]).values
    return out

def main():
    ap = argparse.ArgumentParser(description="Print tables + one plot (workers vs time) by impl.")
    ap.add_argument("csv", nargs="?", help="bench_results_*.csv (if omitted, pick newest)")
    ap.add_argument("--n", type=int, help="choose specific N")
    ap.add_argument("--list-n", action="store_true", help="list all N present and exit")
    args = ap.parse_args()

    csv_path = args.csv or find_latest_csv()
    if not csv_path:
        print("No CSV provided and none found (bench_results_*.csv).", file=sys.stderr)
        sys.exit(2)

    df = load(csv_path)
    agg = aggregate(df)

    if args.list_n:
        ns = sorted(agg["N"].unique())
        print("Available N values:", ns)
        sys.exit(0)

    Nsel = args.n if args.n is not None else pick_best_N(agg)
    subset = agg[agg["N"] == Nsel].copy()

    # Таблица медианных времён
    time_tbl = subset.pivot_table(index="impl", columns="workers",
                                  values="time_s_median", aggfunc="first").sort_index(axis=1).sort_index()
    print_table(f"Median time (s) for N={Nsel}", time_tbl.round(6))

    # Speedup
    sub_sp = compute_speedup(subset)
    speed_tbl = (sub_sp.pivot_table(index="impl", columns="workers",
                                    values="speedup", aggfunc="first")
                        .sort_index(axis=1).sort_index())
    print_table(f"Speedup (T_base/Tp) for N={Nsel}", speed_tbl.round(3))

    # Один график: workers vs time_s_median, линии — реализации
    plt.figure()
    for impl, d in subset.groupby("impl"):
        d = d.sort_values("workers")
        plt.plot(d["workers"].values, d["time_s_median"].values, marker="o", label=impl)
    plt.xlabel("Workers (threads/processes)")
    plt.ylabel("Median time (s)")
    plt.title(f"Time vs Workers (N={Nsel})")
    plt.grid(True, linestyle="--", alpha=0.5)
    plt.legend()
    outpng = f"workers_vs_time_N{Nsel}.png"
    plt.savefig(outpng, bbox_inches="tight", dpi=150)
    print(f"\nSaved plot: {outpng}")

    # Подсказка по содержимому
    impls = ", ".join(sorted(subset['impl'].unique()))
    print(f"Included implementations at N={Nsel}: {impls}")

if __name__ == "__main__":
    main()
