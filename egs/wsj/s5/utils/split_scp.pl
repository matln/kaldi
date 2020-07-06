#!/usr/bin/env perl

# Copyright 2010-2011 Microsoft Corporation

# See ../../COPYING for clarification regarding multiple authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION ANY IMPLIED
# WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR PURPOSE,
# MERCHANTABLITY OR NON-INFRINGEMENT.
# See the Apache 2 License for the specific language governing permissions and
# limitations under the License.


# This program splits up any kind of .scp or archive-type file.
# If there is no utt2spk option it will work on any text  file and
# will split it up with an approximately equal number of lines in
# each but.
# With the --utt2spk option it will work on anything that has the
# utterance-id as the first entry on each line; the utt2spk file is
# of the form "utterance speaker" (on each line).
# It splits it into equal size chunks as far as it can.  If you use the utt2spk
# option it will make sure these chunks coincide with speaker boundaries.  In
# this case, if there are more chunks than speakers (and in some other
# circumstances), some of the resulting chunks will be empty and it will print
# an error message and exit with nonzero status.
# You will normally call this like:
# split_scp.pl scp scp.1 scp.2 scp.3 ...
# or
# split_scp.pl --utt2spk=utt2spk scp scp.1 scp.2 scp.3 ...
# Note that you can use this script to split the utt2spk file itself,
# e.g. split_scp.pl --utt2spk=utt2spk utt2spk utt2spk.1 utt2spk.2 ...

# You can also call the scripts like:
# split_scp.pl -j 3 0 scp scp.0           
# 3: num_jobs, 0: job_id
# [note: with this option, it assumes zero-based indexing of the split parts,
# i.e. the second number must be 0 <= n < num-jobs.]

use warnings;

$num_jobs = 0;
$job_id = 0;
$utt2spk_file = "";
$utt2dur_file = "";
$one_based = 0;

for ($x = 1; $x <= 3 && @ARGV > 0; $x++) {
    if ($ARGV[0] eq "-j") {
        shift @ARGV;
        $num_jobs = shift @ARGV;
        $job_id = shift @ARGV;
    }
    # .+: 匹配1次或多次的任何字符
    # 以数字为名的变量保存的是上一次匹配操作中，第n个小括号中所匹配的内容
    if ($ARGV[0] =~ /--utt2spk=(.+)/) {
        $utt2spk_file=$1;
        shift;
    }

    if ($ARGV[0] =~ "--utt2dur=(.+)") {
        $utt2dur_file=$1;
        shift;
    }

    # one-based: job_id从0或1开始
    if ($ARGV[0] eq '--one-based') {
        $one_based = 1;
        shift @ARGV;
    }
}

if ($num_jobs != 0 && ($num_jobs < 0 || $job_id - $one_based < 0 ||
                       $job_id - $one_based >= $num_jobs)) {
  die "$0: Invalid job number/index values for '-j $num_jobs $job_id" .
      ($one_based ? " --one-based" : "") . "'\n"

}

# TODO
$one_based
    and $job_id--;

if(($num_jobs == 0 && @ARGV < 2) || ($num_jobs > 0 && (@ARGV < 1 || @ARGV > 2))) {
    die
"Usage: split_scp.pl [--utt2spk=<utt2spk_file>] [--utt2dur=<utt2dur_file>] in.scp out1.scp out2.scp ...
   or: split_scp.pl -j num-jobs job-id [--one-based] [--utt2spk=<utt2spk_file>] [--utt2dur=<utt2dur_file>] in.scp [out.scp]
 ... where 0 <= job-id < num-jobs, or 1 <= job-id <- num-jobs if --one-based.\n";
}

$error = 0;
$inscp = shift @ARGV;
# ex: @ARGV=(wav_train.1.scp, wav_train.2.scp, wav_train.3.scp)
# if $num_jobs > 0, and job_id=1, @OUTPUTS=("/dev/null", wav_train.1.scp, "/dev/null")
if ($num_jobs == 0) { # without -j option
    @OUTPUTS = @ARGV;
} else {
    for ($j = 0; $j < $num_jobs; $j++) {
        if ($j == $job_id) {
            if (@ARGV > 0) { push @OUTPUTS, $ARGV[0]; }
            else { push @OUTPUTS, "-"; }
        } else {
            push @OUTPUTS, "/dev/null";
        }
    }
}
# 如果加上了--utt2spk和--utt2dur选项
# 此时根据duration对scp进行划分，使得划分后的utterance总时长尽量相等
if ($utt2spk_file ne "" && $utt2dur_file ne "" ) {  # --utt2spk and --utt2dur
    # 以只读方式打开
    open(U, "<$utt2spk_file") || die "Failed to open utt2spk file $utt2spk_file";
    while(<U>) {
        @A = split;
        @A == 2 || die "Bad line $_ in utt2spk file $utt2spk_file";
        ($u,$s) = @A;
        $utt2spk{$u} = $s;
    }
    $dursum = 0.0;
    open(U, "<$utt2dur_file") || die "Failed to open utt2dur file $utt2dur_file";
    while(<U>) {
        @A = split;
        @A == 2 || die "Bad line $_ in utt2spk file $utt2dur_file";
        ($u,$d) = @A;
        $utt2dur{$u} = $d;
        $dursum += $d;
    }
    open(I, "<$inscp") || die "Opening input scp file $inscp";
    @spkrs = ();
    while(<I>) {
        @A = split;
        if(@A == 0) { die "Empty or space-only line in scp file $inscp"; }
        $u = $A[0];
        $s = $utt2spk{$u};
        if(!defined $s) { die "No such utterance $u in utt2spk file $utt2spk_file"; }
        # where defined $spk_count? 在perl中字典不用初始化
        # %spk_count: 每一个spekaer拥有的utterance数量
        if(!defined $spk_count{$s}) {
            push @spkrs, $s;
            $spk_count{$s} = 0;
            $spk_data{$s} = [];  # ref to new empty array.
        }
        if(!defined $spk2utt{$s}) {
            $spk2utt{$s} = [];
        }
        $spk_count{$s}++;
        push @{$spk_data{$s}}, $_;
        push @{$spk2utt{$s}}, $u;
    }

    $numspks = @spkrs;  # number of speakers.
    $numscps = @OUTPUTS; # number of output files.
    if ($numspks < $numscps) {
      die "Refusing to split data because number of speakers $numspks is less " .
          "than the number of output .scp files $numscps";
    }
    for($scpidx = 0; $scpidx < $numscps; $scpidx++) {
        # array中每一个元素是$spk
        $scparray[$scpidx] = []; # [] is array reference.
    }
    # 根据duration对scp文件进行分割
    $splitdur = $dursum / $numscps;
    $dursum = 0.0;
    $scpidx = 0;
    for my $spk (sort (keys %spk2utt)) {
        # $scpcount: 每个scp文件拥有的utterance数量
        $scpcount[$scpidx] += $spk_count{$spk};
        push @{$scparray[$scpidx]}, $spk;
        for my $utt (@{$spk2utt{$spk}}) {
            $dur = $utt2dur{$utt};
            $dursum += $dur;
        }
        # 把同一个speaker的utterance都分在同一个scp文件内
        if ( $dursum >= $splitdur ) {
            $scpidx += 1;
            $dursum = 0.0;
        }
    }

    # Because scpidx might not have gone up to numscps (because all utts from one
    # speaker go into one split means a major imbalance will mean not all splits
    # are filled), move one speaker inside scparray to the indices which don't have
    # any.
    # 从当前$scpidx开始，给当前还没填满的scp以及后面还没开始填的scp，每个分配一个
    # speaker，speaker从第一个scp里拿，直到第一个scp中只剩下一个speaker
    if ( $scpidx + 1 < $numscps || @{$scparray[$scpidx]} == 0 ) {
        # $scpdone: 前面代码把所有的utterance分完后，填了多少个scp文件
        $scpdone = $scpidx;
        if ( @{$scparray[$scpidx]} == 0 ) {
            # 把倒数第二个scp填满后，utterance正好用完了
            $scpdone -= 1;
        }
        for(; $scpidx < $numscps; $scpidx++) {
            $i = 0;
            for(; $i < $scpdone; $i++) {
                $numspk = @{$scparray[$i]};
                if ($numspk > 1) {
                    last;
                }
            }
            $spk = pop @{$scparray[$i]};
            $scpcount[$i] -= $spk_count{$spk};

            push @{$scparray[$scpidx]}, $spk;
            $scpcount[$scpidx] += $spk_count{$spk};
        }
    }

    # Now print out the files...
    for($scpidx = 0; $scpidx < $numscps; $scpidx++) {
        $scpfn = $OUTPUTS[$scpidx];
        open(F, ">$scpfn") || die "Could not open scp file $scpfn for writing.";
        $count = 0;
        if(@{$scparray[$scpidx]} == 0) {
            print STDERR "Error: split_scp.pl producing empty .scp file $scpfn (too many splits and too few speakers?)\n";
            $error = 1;
        } else {
            foreach $spk ( sort @{$scparray[$scpidx]} ) {
                print F @{$spk_data{$spk}};
                $count += $spk_count{$spk};
            }
            if($count != $scpcount[$scpidx]) { die "Count mismatch [code error]"; }
        }
        close(F);
    }
} # 如果加上了--utt2spk和--utt2dur选项
# 如果有utt-spk文件，根据说话人数量进行分割，使得分割后每个scp文件中的spk数量
# 尽量相等
elsif ($utt2spk_file ne "") {  # We have the --utt2spk option...

    open($u_fh, '<', $utt2spk_file) || die "$0: Error opening utt2spk file $utt2spk_file: $!\n";
    while(<$u_fh>) {
        @A = split;
        @A == 2 || die "$0: Bad line $_ in utt2spk file $utt2spk_file\n";
        ($u,$s) = @A;
        $utt2spk{$u} = $s;
    }
    close $u_fh;
    open($i_fh, '<', $inscp) || die "$0: Error opening input scp file $inscp: $!\n";
    @spkrs = ();
    while(<$i_fh>) {
        @A = split;
        if(@A == 0) { die "$0: Empty or space-only line in scp file $inscp\n"; }
        $u = $A[0];
        $s = $utt2spk{$u};
        defined $s || die "$0: No utterance $u in utt2spk file $utt2spk_file\n";
        # $spk_count: 说话人$s所拥有的utterance数量
        if(!defined $spk_count{$s}) {
            # 初始化
            push @spkrs, $s;
            $spk_count{$s} = 0;
            # %spk_data: speaker $s 所对应的所有inscp文件中的行
            $spk_data{$s} = [];  # ref to new empty array.
        }
        $spk_count{$s}++;
        push @{$spk_data{$s}}, $_;
    }
    # Now split as equally as possible ..
    # First allocate spks to files by allocating an approximately
    # equal number of speakers.
    $numspks = @spkrs;  # number of speakers.
    $numscps = @OUTPUTS; # number of output files.
    if ($numspks < $numscps) {
      die "$0: Refusing to split data because number of speakers $numspks " .
          "is less than the number of output .scp files $numscps\n";
    }
    for($scpidx = 0; $scpidx < $numscps; $scpidx++) {
        $scparray[$scpidx] = []; # [] is array reference.
    }
    for ($spkidx = 0; $spkidx < $numspks; $spkidx++) {
        $scpidx = int(($spkidx*$numscps) / $numspks);
        $spk = $spkrs[$spkidx];
        push @{$scparray[$scpidx]}, $spk;
        $scpcount[$scpidx] += $spk_count{$spk};
    }

    # TODO: 没看懂原理
    # Now will try to reassign beginning + ending speakers
    # to different scp's and see if it gets more balanced.
    # Suppose objf(objectfunction) we're minimizing is `sum_i (num utts in scp[i] - average)^2`.
    # We can show that if considering changing just 2 scp's, we minimize
    # this by minimizing the squared difference in sizes.  This is
    # equivalent to minimizing the absolute difference in sizes.  This
    # shows this method is bound to converge.
    
    # 这样掐头去尾不会产生scpcount为0的scp吗？不会，因为如果唯一的spk被掐头或
    # 去尾了，此时绝对值是最大的。if判断语句保证了不会产生空的scp

    $changed = 1;
    while($changed) {
        $changed = 0;
        for($scpidx = 0; $scpidx < $numscps; $scpidx++) {
            # First try to reassign ending spk of this scp.
            if($scpidx < $numscps-1) {
                # $sz: scp文件中spk的数量
                $sz = @{$scparray[$scpidx]};
                if($sz > 0) {
                    $spk = $scparray[$scpidx]->[$sz-1];
                    $count = $spk_count{$spk};
                    $nutt1 = $scpcount[$scpidx];
                    $nutt2 = $scpcount[$scpidx+1];
                    if( abs( ($nutt2+$count) - ($nutt1-$count))
                        < abs($nutt2 - $nutt1))  { # Would decrease
                        # size-diff by reassigning spk...
                        $scpcount[$scpidx+1] += $count;
                        $scpcount[$scpidx] -= $count;
                        pop @{$scparray[$scpidx]};
                        unshift @{$scparray[$scpidx+1]}, $spk;
                        $changed = 1;
                    }
                }
            }
            # 什么时候$scpidx=0？$numscps=1
            # 有没有可能@{$scparray[$scpidx]}=0？掐头去尾可能就会出现
            if($scpidx > 0 && @{$scparray[$scpidx]} > 0) {
                $spk = $scparray[$scpidx]->[0];
                $count = $spk_count{$spk};
                $nutt1 = $scpcount[$scpidx-1];
                $nutt2 = $scpcount[$scpidx];
                if( abs( ($nutt2-$count) - ($nutt1+$count))
                    < abs($nutt2 - $nutt1))  { # Would decrease
                    # size-diff by reassigning spk...
                    $scpcount[$scpidx-1] += $count;
                    $scpcount[$scpidx] -= $count;
                    shift @{$scparray[$scpidx]};
                    push @{$scparray[$scpidx-1]}, $spk;
                    $changed = 1;
                }
            }
        }
    }
    # Now print out the files...
    for($scpidx = 0; $scpidx < $numscps; $scpidx++) {
        $scpfile = $OUTPUTS[$scpidx];
        # -: row 107h
        ($scpfile ne '-' ? open($f_fh, '>', $scpfile)
                         : open($f_fh, '>&', \*STDOUT)) ||
            die "$0: Could not open scp file $scpfile for writing: $!\n";
        $count = 0;
        if(@{$scparray[$scpidx]} == 0) {
            print STDERR "$0: eError: split_scp.pl producing empty .scp file " .
                         "$scpfile (too many splits and too few speakers?)\n";
            $error = 1;
        } else {
            foreach $spk ( @{$scparray[$scpidx]} ) {
                print $f_fh @{$spk_data{$spk}};
                $count += $spk_count{$spk};
            }
            $count == $scpcount[$scpidx] || die "Count mismatch [code error]";
        }
        close($f_fh);
    }
} else {
   # This block is the "normal" case where there is no --utt2spk
   # option and we just break into equal size chunks.
   # 将inscp中的所有行进行均分

    open($i_fh, '<', $inscp) || die "$0: Error opening input scp file $inscp: $!\n";

    $numscps = @OUTPUTS;  # size of array.
    @F = ();
    while(<$i_fh>) {
        push @F, $_;
    }
    $numlines = @F;
    if($numlines == 0) {
        print STDERR "$0: error: empty input scp file $inscp\n";
        $error = 1;
    }
    $linesperscp = int( $numlines / $numscps); # the "whole part"..
    $linesperscp >= 1 || die "$0: You are splitting into too many pieces! [reduce \$nj]\n";
    $remainder = $numlines - ($linesperscp * $numscps);
    # 可能会出现坏的remainder吗？比如$numscps=0
    ($remainder >= 0 && $remainder < $numlines) || die "bad remainder $remainder";
    # [just doing int() rounds down].
    $n = 0;
    for($scpidx = 0; $scpidx < @OUTPUTS; $scpidx++) {
        $scpfile = $OUTPUTS[$scpidx];
        ($scpfile ne '-' ? open($o_fh, '>', $scpfile)
                         : open($o_fh, '>&', \*STDOUT)) ||
            die "$0: Could not open scp file $scpfile for writing: $!\n";
        # 0 <= $remainder < $numscps, 把remainder放在前面几个划分的scp里，每个scp 1个
        for($k = 0; $k < $linesperscp + ($scpidx < $remainder ? 1 : 0); $k++) {
            print $o_fh $F[$n++];
        }
        close($o_fh) || die "$0: Eror closing scp file $scpfile: $!\n";
    }
    $n == $numlines || die "$n != $numlines [code error]";
}

exit ($error);
