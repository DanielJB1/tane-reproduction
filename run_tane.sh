#!/bin/bash
# run_tane.sh - build TANE 1.0 and run all three programs on a dataset.
# Put this file in the tane-1.0 folder (next to src/, bin/, data/) and run:
#   bash run_tane.sh                                   (uses the sample data)
#   bash run_tane.sh data/xyz.dat ROWS ATTRS [EPS]     (your own dataset)
set -e
cd "$(dirname "$0")"
export LC_ALL=C   # dot as decimal separator, also on a Dutch Mac

DATA=${1:-data/testadata.dat}
ROWS=${2:-100}
ATTRS=${3:-11}
EPS=${4:-0.1}
NAME=$(basename "$DATA" .dat)
OUT=results/$NAME
mkdir -p "$OUT"

# 1. build (only the first time)
if [ ! -x bin/tanemem ]; then
  echo "Building..."
  (cd src && make CC=cc > ../results/build.log 2>&1)
fi

# 2. convert the sample data (only the first time)
if [ "$DATA" = data/testadata.dat ] && [ ! -f "$DATA" ]; then
  (cd descriptions && perl ../bin/select.perl testadata.dsc)
fi

# 3. run, saving the full output and the time of each program
run () {  # run <label> <command...>
  local label=$1; shift
  local start end
  start=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  "$@" > "$OUT/$label.log" 2> "$OUT/$label.progress"   # keep the two streams apart
  end=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  local n
  n=$(grep -c -- '->' "$OUT/$label.log" || true)
  printf "%-22s %8s deps   %8.3f s\n" "$label" "$n" "$(echo "$end - $start" | bc)" | tee -a "$OUT/summary.txt"
}

: > "$OUT/summary.txt"
echo "Dataset: $DATA  ($ROWS rows, $ATTRS attributes)" | tee -a "$OUT/summary.txt"
run tane            bin/tane    "$ATTRS" "$ROWS" "$ATTRS" "$DATA"
run tanemem         bin/tanemem "$ATTRS" "$ROWS" "$ATTRS" "$DATA"
run "taneg3_eps$EPS" bin/taneg3 "$ATTRS" "$ROWS" "$ATTRS" "$DATA" "$EPS"

# sorted dependency lists, handy for diff-ing against your own implementation
grep -- '->' "$OUT/tanemem.log" | sort > "$OUT/fds_sorted.txt"

echo
echo "Results saved in: $(pwd)/$OUT"
