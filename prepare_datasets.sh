#!/bin/bash
# prepare_datasets.sh - download, clean and convert the datasets used in the TANE paper.
# Put this file in the tane-1.0 folder and run:   bash prepare_datasets.sh
#
# Result: data/<name>.dat (TANE input) for every dataset, and data/datasets.txt
# listing "name rows attributes" for run_experiments.sh.
set -e
cd "$(dirname "$0")"

UCI=https://archive.ics.uci.edu/ml/machine-learning-databases
RAW=original/raw
mkdir -p "$RAW" data descriptions

# ---------------------------------------------------------------- 1. download
# name|url  (a file you already put in original/raw/ yourself is not downloaded again)
FILES="
lymphography.data|$UCI/lymphography/lymphography.data
hepatitis.data|$UCI/hepatitis/hepatitis.data
breast-cancer-wisconsin.data|$UCI/breast-cancer-wisconsin/breast-cancer-wisconsin.data
adult.data|$UCI/adult/adult.data
adult.test|$UCI/adult/adult.test
krkopt.data|$UCI/chess/king-rook-vs-king/krkopt.data
"
for entry in $FILES; do
  file=${entry%%|*}
  url=${entry#*|}
  if [ ! -s "$RAW/$file" ]; then
    echo "Downloading $file ..."
    if ! curl -fsSL -o "$RAW/$file" "$url"; then
      rm -f "$RAW/$file"
      echo "  Could not download $file. Download it by hand from https://archive.ics.uci.edu"
      echo "  and put it in $(pwd)/$RAW/ , then run this script again."
      exit 1
    fi
  fi
done

# ---------------------------------------------------------------- 2. clean
# - remove Windows line endings, empty lines and comment lines starting with '|'
# - remove spaces around commas (Adult uses ", ")
# Missing values '?' are kept: TANE treats them as an ordinary value.
clean () {  # clean <strip_trailing_dot 0/1> <input files...>
  local dot=$1; shift
  perl -ne '
    BEGIN { $dot = shift @ARGV }
    s/\r//g; chomp;
    next if /^\s*$/ or /^\|/;
    s/\s*,\s*/,/g; s/^\s+|\s+$//g;
    s/\.$// if $dot;
    print "$_\n";' "$dot" "$@"
}
clean 0 "$RAW/lymphography.data"           > original/lymphography.csv
clean 0 "$RAW/hepatitis.data"              > original/hepatitis.csv
clean 0 "$RAW/breast-cancer-wisconsin.data" > original/wisconsin.csv
# The trailing '.' in adult.test (">50K.") is KEPT on purpose: the authors did not remove it,
# and only with it do you get the paper's 85 dependencies (removing it gives 66).
{ clean 0 "$RAW/adult.data"; clean 0 "$RAW/adult.test"; } > original/adult.csv
clean 0 "$RAW/krkopt.data"                 > original/chess.csv

# ---------------------------------------------------------------- 3. convert
# Writes a description file and runs the authors' converter select.perl.
: > data/datasets.txt
convert () {  # convert <output name> <cleaned csv> <number of copies> <expected rows>
  local name=$1 csv=$2 copies=$3 expected=$4
  cat > "descriptions/$name.dsc" <<EOF
Umask = 007
DataIn = ../original/$csv
NoOfCopies = $copies
StandardOut = ../data/$name.dat
EOF
  (cd descriptions && perl ../bin/select.perl "$name.dsc")
  local rows attrs
  rows=$(wc -l < "data/$name.dat" | tr -d ' ')
  attrs=$(head -1 "data/$name.dat" | awk -F, '{print NF}')
  echo "$name $rows $attrs" >> data/datasets.txt
  local note=""
  [ "$rows" != "$expected" ] && note="   <-- paper has $expected rows"
  printf "%-16s %8s rows  %3s attributes%s\n" "$name" "$rows" "$attrs" "$note"
}

echo
echo "Converted datasets:"
convert lymphography lymphography.csv 1 148
convert hepatitis    hepatitis.csv    1 155
for n in 1 2 4 8 16 32 64 128 256 512; do
  convert "wisconsin_x$n" wisconsin.csv "$n" $((699 * n))
done
convert adult        adult.csv        1 48842
convert chess        chess.csv        1 28056

echo
echo "Done. Next step:  bash run_experiments.sh"
