#!/bin/bash
# run_experiments.sh - rerun the experiments of Tables 1 and 2 of the TANE paper.
# Run prepare_datasets.sh first. Then, in the tane-1.0 folder:
#   bash run_experiments.sh            (each single run stops after 1800 s)
#   bash run_experiments.sh 600        (other time limit, in seconds)
#
# Output: results/all_results.csv with your counts and times next to the paper's,
#         and the full output of every run in results/logs/.
cd "$(dirname "$0")"
export LC_ALL=C   # dot as decimal separator, also on a Dutch Mac
LIMIT=${1:-1800}
LOGS=results/logs
CSV=results/all_results.csv
mkdir -p "$LOGS"

[ -x bin/tanemem ] || (cd src && make CC=cc > ../results/build.log 2>&1) \
  || { echo "Build failed, see results/build.log"; exit 1; }
[ -f data/datasets.txt ] || { echo "Run prepare_datasets.sh first."; exit 1; }

# Numbers reported in the paper: "N time" per program and epsilon ('-' = not reported)
paper () {  # paper <dataset> <program> <eps>
  local ds=$1 eps=$3
  case "$1/$2/$3" in
    lymphography/tane/0)      echo "2730 68" ;;
    lymphography/tanemem/0)   echo "2730 24" ;;
    hepatitis/tane/0)         echo "8250 30" ;;
    hepatitis/tanemem/0)      echo "8250 14" ;;
    wisconsin_x1/tane/0)      echo "46 1" ;;
    wisconsin_x1/tanemem/0)   echo "46 0.25" ;;
    wisconsin_x2/tanemem/0)   echo "46 0.5" ;;
    wisconsin_x4/tanemem/0)   echo "46 1.1" ;;
    wisconsin_x8/tanemem/0)   echo "46 2.4" ;;
    wisconsin_x16/tanemem/0)  echo "46 5.1" ;;
    wisconsin_x32/tanemem/0)  echo "46 11.0" ;;
    wisconsin_x64/tane/0)     echo "46 81" ;;
    wisconsin_x64/tanemem/0)  echo "46 23" ;;
    wisconsin_x128/tane/0)    echo "46 173" ;;
    wisconsin_x128/tanemem/0) echo "46 247" ;;
    wisconsin_x512/tane/0)    echo "46 884" ;;
    adult/tane/0)             echo "85 1451" ;;
    chess/tane/0)             echo "1 4" ;;
    chess/tanemem/0)          echo "1 2" ;;
    wisconsin_x*/tane*/0)     echo "46 -" ;;
    lymphography/taneg3/*)    t2 "$eps" "3388 22.2" "7031 4.9" "6383 3.7" "21 0.0" ;;
    hepatitis/taneg3/*)       t2 "$eps" "9666 14.6" "6617 9.3" "2630 4.2" "160 0.0" ;;
    chess/taneg3/*)           t2 "$eps" "1 2.6" "1 3.1" "1 3.5" "17 3.6" ;;
    wisconsin_x*/taneg3/*)
      local t
      case ${ds#wisconsin_x} in
        1) t="0.3 0.2 0.2 0.0";;    2) t="0.5 0.5 0.4 0.1";;    4) t="1.1 1.0 0.9 0.2";;
        8) t="2.3 2.0 1.9 0.4";;   16) t="4.9 4.4 4.3 0.8";;   32) t="10.6 9.3 8.9 1.8";;
       64) t="26.7 20.3 19.2 3.9";; *) t="- - - -";;
      esac
      set -- $t
      t2 "$eps" "113 $1" "126 $2" "141 $3" "18 $4" ;;
    *) echo "- -" ;;
  esac
}
t2 () {  # pick the value for eps 0.01 / 0.05 / 0.1 / 0.5
  case $1 in 0.01) echo "$2";; 0.05) echo "$3";; 0.1) echo "$4";; 0.5) echo "$5";; *) echo "- -";; esac
}

now () { perl -MTime::HiRes=time -e 'printf "%.3f", time'; }

run () {  # run <dataset> <rows> <attrs> <program> <eps>
  local name=$1 rows=$2 attrs=$3 prog=$4 eps=$5
  local log="$LOGS/${name}_${prog}_eps${eps}.log"
  local args=("$attrs" "$rows" "$attrs" "data/$name.dat")
  [ "$prog" = taneg3 ] && args+=("$eps")
  local start end secs status n
  start=$(now)
  # dependencies (stdout) and progress lines (stderr) go to separate files,
  # otherwise they get spliced together mid-line and the count is wrong
  perl -e 'alarm shift; exec @ARGV' "$LIMIT" "bin/$prog" "${args[@]}" > "$log" 2> "${log%.log}.progress"
  status=$?
  end=$(now)
  secs=$(perl -e 'printf "%.3f", $ARGV[1] - $ARGV[0]' "$start" "$end")
  n=$(grep -c -- '->' "$log" || true)
  [ $status -ne 0 ] && { [ $status -eq 142 ] && n="timeout" || n="error($status)"; }
  local p; p=$(paper "$name" "$prog" "$eps")
  set -- $p
  local pn=$1 pt=$2
  local match=""
  [ "$pn" != "-" ] && { [ "$n" = "$pn" ] && match=yes || match=NO; }
  echo "$name,$rows,$attrs,$prog,$eps,$n,$secs,$pn,$pt,$match" >> "$CSV"
  printf "%-15s %-8s eps=%-5s %10s deps (paper %5s)  %9.2f s (paper %s s)\n" \
         "$name" "$prog" "$eps" "$n" "$pn" "$secs" "$pt"
}

echo "dataset,rows,attributes,program,epsilon,deps_found,seconds,paper_deps,paper_seconds,deps_match" > "$CSV"
while read -r name rows attrs; do
  # Table 1: exact dependencies with TANE (disk) and TANE/MEM
  run "$name" "$rows" "$attrs" tanemem 0
  run "$name" "$rows" "$attrs" tane    0
  # Table 2: approximate dependencies (the paper skips Adult and Wisconsin x128 and larger)
  case $name in adult|wisconsin_x128|wisconsin_x256|wisconsin_x512) continue;; esac
  for eps in 0.01 0.05 0.1 0.5; do
    run "$name" "$rows" "$attrs" taneg3 "$eps"
  done
done < data/datasets.txt

echo
echo "All results: $(pwd)/$CSV"
