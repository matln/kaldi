#!/usr/bin/env bash

# this script is used for comparing decoding results between systems.
# e.g. local/chain/compare_wer.sh exp/chain/tdnn_{c,d}_sp
# For use with discriminatively trained systems you specify the epochs after a colon:
# for instance,
# local/chain/compare_wer.sh exp/chain/tdnn_c_sp exp/chain/tdnn_c_sp_smbr:{1,2,3}


if [ $# == 0 ]; then
  echo "Usage: $0: [--looped] [--online] <dir1> [<dir2> ... ]"
  echo "e.g.: $0 exp/chain/tdnn_{b,c}_sp"
  echo "or (with epoch numbers for discriminative training):"
  echo "$0 exp/chain/tdnn_b_sp_disc:{1,2,3}"
  exit 1
fi

echo "# $0 $*"

include_looped=false
if [ "$1" == "--looped" ]; then
  include_looped=true
  shift
fi
include_online=false
if [ "$1" == "--online" ]; then
  include_online=true
  shift
fi


used_epochs=false

# this function set_names is used to separate the epoch-related parts of the name
# [for discriminative training] and the regular parts of the name.
# If called with a colon-free directory name, like:
#  set_names exp/chain/tdnn_lstm1e_sp_bi_smbr
# it will set dir=exp/chain/tdnn_lstm1e_sp_bi_smbr and epoch_infix=""
# If called with something like:
#  set_names exp/chain/tdnn_d_sp_smbr:3
# it will set dir=exp/chain/tdnn_d_sp_smbr and epoch_infix="_epoch3"


set_names() {
  if [ $# != 1 ]; then
    echo "compare_wer_general.sh: internal error"
    exit 1  # exit the program
  fi
  dirname=$(echo $1 | cut -d: -f1)
  epoch=$(echo $1 | cut -s -d: -f2)
  if [ -z $epoch ]; then
    epoch_infix=""
  else
    used_epochs=true
    epoch_infix=_epoch${epoch}
  fi
}



echo -n "# System                     "
for x in $*; do   printf "% 10s" " $(basename $x)";   done
echo

strings=(
  "# WER on dev(fglarge)        "
  "# WER on dev(tglarge)        "
  "# WER on dev(tgmed)          "
  "# WER on dev(tgsmall)        "
  "# WER on dev_other(fglarge)  "
  "# WER on dev_other(tglarge)  "
  "# WER on dev_other(tgmed)    "
  "# WER on dev_other(tgsmall)  "
  "# WER on test(fglarge)       "
  "# WER on test(tglarge)       "
  "# WER on test(tgmed)         "
  "# WER on test(tgsmall)       "
  "# WER on test_other(fglarge) "
  "# WER on test_other(tglarge) "
  "# WER on test_other(tgmed)   "
  "# WER on test_other(tgsmall) ")

for n in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
   echo -n "${strings[$n]}"
   for x in $*; do
     set_names $x  # sets $dirname and $epoch_infix
     decode_names=(dev_clean_fglarge dev_clean_tglarge dev_clean_tgmed dev_clean_tgsmall dev_other_fglarge dev_other_tglarge dev_other_tgmed dev_other_tgsmall test_clean_fglarge test_clean_tglarge test_clean_tgmed test_clean_tgsmall test_other_fglarge test_other_tglarge test_other_tgmed test_other_tgsmall)

     wer=$(grep WER $dirname/decode_${decode_names[$n]}/wer_* | utils/best_wer.sh | awk '{print $2}')
     printf "% 10s" $wer
   done
   echo
   if $include_looped; then
     echo -n "#             [looped:]    "
     for x in $*; do
       set_names $x  # sets $dirname and $epoch_infix
       wer=$(grep WER $dirname/decode_looped_${decode_names[$n]}/wer_* | utils/best_wer.sh | awk '{print $2}')
       printf "% 10s" $wer
     done
     echo
   fi
   if $include_online; then
     echo -n "#             [online:]    "
     for x in $*; do
       set_names $x  # sets $dirname and $epoch_infix
       wer=$(grep WER ${dirname}_online/decode_${decode_names[$n]}/wer_* | utils/best_wer.sh | awk '{print $2}')
       printf "% 10s" $wer
     done
     echo
   fi
done


if $used_epochs; then
  exit 0;  # the diagnostics aren't comparable between regular and discriminatively trained systems.
fi


echo -n "# Final train prob           "
for x in $*; do
  prob=$(grep Overall $x/log/compute_prob_train.final.log | grep -v xent | awk '{printf("%.4f", $8)}')
  printf "% 10s" $prob
done
echo

echo -n "# Final valid prob           "
for x in $*; do
  prob=$(grep Overall $x/log/compute_prob_valid.final.log | grep -v xent | awk '{printf("%.4f", $8)}')
  printf "% 10s" $prob
done
echo

echo -n "# Final train prob (xent)    "
for x in $*; do
  prob=$(grep Overall $x/log/compute_prob_train.final.log | grep -w xent | awk '{printf("%.4f", $8)}')
  printf "% 10s" $prob
done
echo

echo -n "# Final valid prob (xent)    "
for x in $*; do
  prob=$(grep Overall $x/log/compute_prob_valid.final.log | grep -w xent | awk '{printf("%.4f", $8)}')
  printf "% 10s" $prob
done
echo

echo -n "# Num-parameters             "
for x in $*; do
  num_params=$(grep num-parameters $x/log/progress.1.log | awk '{print $2}')
  printf "% 10d" $num_params
done
echo
