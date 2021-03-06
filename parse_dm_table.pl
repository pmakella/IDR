#!/usr/bin/perl
BEGIN {
	push @INC, "/home/malijia/bin/";
}
use strict;
use Lijia;

# pmakella@uchicago.edu
# 05-16-2014
# using R3.0 for parallel processing
# 03-06-2014
# new updates
# remove peaks in blacklist for dm and ce
# make temp dir for spp and remove it at the end
# 02-10-2014
# scp with pmakella login, no chr genome /raid/database/.. to get chr names in input wig
# 06-11-2013
# match rep numbers between log and config
#
# pmakella@uchicago.edu
# 05-23-2013
# new naming Strain_Tissue_Stage_Source_AntibodyID_Rep#
#
# 05-07-2013
# added $! to wait, $! gives the pid of the last process
#
# pmakella@uchicago.edu
# 04-09-2013
# removed leading and trailing spaces from config file entries
#
# ljma@uchicago.edu
# 03-28-2013
# (1) Report summary information to screen.
# (2) modified the regular expression of $url, to remove the reads number info in that field in the config table
#
# 03-11-2013
# (1) generate BED3+3 from broad peak output (regionPeak.gz) for browser
#
# 03-01-2013
# (1) modify bin_dir related parameters in both config/code
#	delete spp_dir
#	link all required in-house scripts/public tools to /usr/local/bin/
# (2) change naming rules for UC sequencing samples. (BID was not used in file names)

# 02-26-2013
# (1) add "species" in config file
# (2) add "sh run.sh" to the end of "download.sh"
#
# 02-23-2013
# (1) add "prj_dir" in config file
# (2) modify "download.sh" output
#
# 02-03-2013
# Fit dm config table
# Strain_Tissue_TFname_STAGE_Ab_Replicate

# 01-29-2013
# using SPP to estimate fragment size and call peaks
# using IDR to estimate consistency
# Np/Nt<2
# Nsc>1.06

# 01-18-2013
# Parse name/URL from worm table 
# Nameing rule:
# TFname_STAGE_OP_Ab_Replicate
#  

if (@ARGV != 1) {
	print "usage: dm.config\n";
	exit;
}

Ptime("start!");
###### Get config information
my $config = shift;
open(CONFIG, $config) or die $!;
my(%Config);
while (<CONFIG>) {
	chomp;
	next if ($_=~/^\#/);
	my@info=split/\t/;
	$Config{$info[0]}=$info[1];
}
close CONFIG;

my$out_dir=$Config{'out_dir'};
my$prj_dir=$Config{'prj_dir'};
my$fastq_suffix=$Config{'fastq_suffix'};
my$node=$Config{'node'};
my$IDR_true=$Config{'IDR_true'};
my$IDR_pr=$Config{'IDR_pr'};
my$npeaks=$Config{'npeaks'};
my$bin_dir=$Config{'bin_dir'};
my$genome_table;
my$black_list;
my$genome_bedtools;
my$R2_15dir="/home/padma/R-2.15.1/bin";
my$R3_0dir="/home/padma/R-3.0.0/bin";

if ($Config{'sp'} eq "dm") {
	$genome_table = "genome_table.Dmel5.41.txt";
	$genome_bedtools = "dm3.nochr.genome";
	$black_list = "dm3-blacklist.bed";
}elsif ($Config{'sp'} eq "ce") {
	$genome_table = "genome_table.worm.ws220.txt";
	$genome_bedtools = "ce10.genome";
	$black_list = "ce10-blacklist.bed";
}else{
	print "ERROR! $Config{'sp'} Please specifiy genome table for this species!\n";
	exit;
}
print "\n#### configure parameters
date\t$Config{'date'}
reference\t$Config{'reference'}
bin_dir\t$Config{'bin_dir'}
out_dir\t$Config{'out_dir'}
prj_dir\t$Config{'prj_dir'}
node\t$Config{'node'}
IDR_true_threshold\t$Config{'IDR_true'}
IDR_pr_threshold\t$Config{'IDR_pr'}
num_of_start_peaks\t$Config{'npeaks'}
library_prep\t$Config{'library'}
\n";


###############################################################################
open(IN1, "$out_dir/processing/$Config{'date'}/$Config{'sp'}_table_$Config{'date'}.txt") or die $!;
open(OUT1, ">$out_dir/raw/download_$Config{'date'}.sh") or die $!;
open(OUT2, ">$out_dir/processing/$Config{'date'}/run_$Config{'date'}.sh") or die $!;
open(OUT3, ">$out_dir/processing/$Config{'date'}/report_$Config{'date'}.sh") or die $!;

###### Get dataset information from data production table
print "#### factors\n";
my$l=0;
my(%Dataset);
while (<IN1>) {
	chomp;
	my @info = split/\t/;
#	my @info = split(/\s+/);
	#print @info;
	next if ($info[7] eq "");
	$l++;
	my $url = $info[7];
	my $search_string = quotemeta "$Config{'fastq_suffix'}";
#	$url =~ /(([\w|\_|\.|\-]+?).$search_string?[.gz])*/;
	$url =~ /(([\w|\_|\.|\-]+?).$search_string?[.gz|\w]+)*/;
	my $url=$1;
	my $file=$2;
#	print "$url\n";
#	print "$file\n";
	
	#trim leading and trailing spaces
	my $str;
	foreach (@info) {
		$str= $_;
		$str =~ s/^\s+//;
		$str =~ s/\s+$//;
		$_ = $str;
	}
# Strain_Tissue_STAGE_src_AbID_Replicate
	#my $factor = "$info[7]_$info[2]_$info[5]_$info[6]";
	my $factor = "$info[1]_$info[2]_$info[3]";
	my $source = $info[4];
	if ($source eq "Antibody" || $source eq "IP") {
	#	$source = "Antibody";
	# Padma: new naming
		$source = "IP"
	}
	if ($source eq "Input" || $source eq "INPUT" || $source eq "DNA") {
		$source = "Input";
	}
	my $replicate = $info[6];
	my $abid = $info[5];
	my $name = "$factor\_$source\_$abid\_Rep$replicate";
	print OUT1 "scp pmakella\@sullivan.opensciencedatacloud.org:$prj_dir/$url ./\n";
	if ($url =~ /.gz$/) {
		print OUT1 "gzip -d $file.$Config{'fastq_suffix'}.gz\n";
	}else{
	}
	if (!defined $Dataset{$factor}{$source}{$replicate}) {
		print OUT1 "mv $file.$Config{'fastq_suffix'} $name.$Config{'fastq_suffix'}\n\n";
		$Dataset{$factor}{$source}{$replicate}=$name;
	}else{
		print OUT1 "cat $file.$Config{'fastq_suffix'} >> $Dataset{$factor}{$source}{$replicate}.$Config{'fastq_suffix'}\n\n";
		print "!!!!!!!!!@@@@@@@@ WARNING: $factor\_$source\_Rep$replicate has duplicated files, will be merged for processing\n";
	}
	print "$factor\t$source\t$abid\t$replicate\t$file.$Config{'fastq_suffix'}\n";
}
close IN1;

my$dn=keys %Dataset;
print "\n\n#### Summary: 
$dn Datasets were imported!
$l fastq files are being processed!
\n";

###### Organize data sets, do alignment
my(%Peakset);
print OUT2 "############ Organize data sets, and run alignment\n";
print OUT2 "ln -fs $Config{'bin_dir'}/idrCode/genome_tables/$genome_table genome_table.txt\n";
print OUT2 "ln -fs $Config{'bin_dir'}/idrCode/*.r ./\n";
#print OUT2 "cat genome_table.txt | awk '{print \$1\"\\t\"\$2}' > genome_table.bedtools.txt\n";
foreach my $d (sort {$a cmp $b} keys %Dataset) {
	print OUT2 "###### Dataset $d
	echo \"MSG: running alignment for $d\"
	";
	my($all_inputs,$all_ips);
	foreach my $r (sort {$a <=> $b} keys %{$Dataset{$d}{'IP'}}) {
		my$ip = $Dataset{$d}{'IP'}{$r};
		$Peakset{$d}.="$ip\t";
		print OUT2 "## dataset $d IP replicate $r
			bwa aln -I -B 0 -t $node  $Config{'reference'}  $out_dir/raw/$ip.$fastq_suffix > $ip.sai
			bwa samse $Config{'reference'} $ip.sai $out_dir/raw/$ip.$fastq_suffix > $ip.sam
			samtools view -F 1548 -h -S -q 30 -o $ip\_q30.sam $ip.sam
			samtools view -Sb $ip\_q30.sam | bamToBed -i stdin | awk 'BEGIN{FS=\"\\t\";OFS=\"\\t\"}{\$4=\"N\";print\$0}' | gzip -c > $ip.tagAlign.gz
			$Config{'bin_dir'}/shuf.sh $ip.tagAlign.gz ./ $ip
			";
		$all_ips .= "$ip.tagAlign.gz\t";
	}
	foreach my $r (sort {$a <=> $b} keys %{$Dataset{$d}{'Input'}}) {
		my$input = $Dataset{$d}{'Input'}{$r};
		print OUT2 "## dataset $d Input replicate $r
			bwa aln -I -B 0 -t $node $Config{'reference'} $out_dir/raw/$input.$fastq_suffix > $input.sai
			bwa samse $Config{'reference'} $input.sai $out_dir/raw/$input.$fastq_suffix > $input.sam
			samtools view -F 1548 -h -S -q 30 -o $input\_q30.sam $input.sam
			samtools view -Sb $input\_q30.sam | bamToBed -i stdin | awk 'BEGIN{FS=\"\\t\";OFS=\"\\t\"}{\$4=\"N\";print\$0}' | gzip -c > $input.tagAlign.gz
			";
		$all_inputs .= "$input.tagAlign.gz\t";
	}

	print OUT2 "## pool all IPs and inputs
		zcat $all_ips | gzip -c > $d\_IP_Rep0.tagAlign.gz
		zcat $all_inputs | gzip -c > $d\_Input_Rep0.tagAlign.gz
		bedToBam -i $d\_Input_Rep0.tagAlign.gz -g /raid/database/$genome_bedtools > $d\_Input_Rep0.bam
		\n";
	print OUT2 "# generate IP pooled-pseduoreplicates
		$Config{'bin_dir'}/shuf.sh $d\_IP_Rep0.tagAlign.gz ./ $d\_IP_Rep0
		\n";
}
print OUT2 "perl $Config{'bin_dir'}/SAM.statistics.bwa.pl ./ $Config{'date'}.SAM.stats &\n\n\n";


###### run SPP and IDR
print OUT2 "############ SPP and IDR\n";
print OUT2 "###create temp dir for SPP
mkdir tmpspp/
\n";
foreach my $d (sort {$a cmp $b} keys %Peakset) {
	print OUT2 "###### Dataset\t$d
	echo \"MSG: running SPP and IDR for $d\"
	echo \"MSG: IPs: $Peakset{$d}\"
	echo \"MSG: Inputs: $d\_Input_Rep0.tagAlign.gz\"
	max_numPeaks_Rep=0
	max_numPeaks_Rep_macs2=0
	\n";
	print OUT3 "###### Dataset\t$d
	echo \"IDR-filtered SPP/MACS2 $d\"
	echo \"IPs:\t$Peakset{$d}\"
	echo \"Inputs:\t$d\_Input_Rep0.tagAlign.gz\"
	max_numPeaks_Rep=0
	max_numPeaks_Rep_macs2=0
	\n";
	my@IPs=split/\t/,$Peakset{$d};
	my(@IDR_pairs,@IDR_pairs_macs);
	for(my$i=0;$i<@IPs;$i++){
		
		print OUT2 "# peak calls: original replicates and self-pesduoreplicates $IPs[$i]
			$R3_0dir/Rscript $Config{'bin_dir'}/run_spp.wig.R -c=$IPs[$i].tagAlign.gz -i=$d\_Input_Rep0.tagAlign.gz -npeak=$npeaks -tmpdir=./tmpspp  -odir=./  -p=$node -savr  -savp -rf -out=$Config{'date'}.cc

			gzip -cdf $IPs[$i].tagAlign.gz > $IPs[$i].tagAlign	
			$R2_15dir/Rscript $bin_dir/spp_wig_tagAlign.R  --args  --baseDir=./ --outDir=./ --factor=\"$IPs[$i].tagAlign\" --ipFile=$IPs[$i].tagAlign

			ss=\$(cat $Config{'date'}.cc | grep $IPs[$i].tagAlign.gz | cut -f3 | head -n 1 | cut -d \",\" -f1)
			macs2 callpeak -t $IPs[$i].tagAlign.gz -c $d\_Input_Rep0.tagAlign.gz -g dm --to-large --nomodel --shiftsize \$ss -p 0.1 -n $IPs[$i]_VS_$d\_Input_Rep0 &
			$R3_0dir/Rscript $Config{'bin_dir'}//run_spp.R -c=$IPs[$i].pr1.tagAlign.gz -i=$d\_Input_Rep0.tagAlign.gz -npeak=$npeaks -tmpdir=./tmpspp  -odir=./   -p=$node -savr  -savp -rf -out=$Config{'date'}.cc
			ss=\$(cat $Config{'date'}.cc | grep $IPs[$i].pr1.tagAlign.gz | cut -f3 | head -n 1 | cut -d \",\" -f1)
			macs2 callpeak -t $IPs[$i].pr1.tagAlign.gz -c $d\_Input_Rep0.tagAlign.gz -g dm --to-large --nomodel --shiftsize \$ss -p 0.1 -n $IPs[$i].pr1_VS_$d\_Input_Rep0 &
			$R3_0dir/Rscript $Config{'bin_dir'}//run_spp.R -c=$IPs[$i].pr2.tagAlign.gz -i=$d\_Input_Rep0.tagAlign.gz -npeak=$npeaks -tmpdir=./tmpspp  -odir=./   -p=$node -savr  -savp -rf -out=$Config{'date'}.cc
			ss=\$(cat $Config{'date'}.cc | grep $IPs[$i].pr2.tagAlign.gz | cut -f3 | head -n 1 | cut -d \",\" -f1)
			macs2 callpeak -t $IPs[$i].pr2.tagAlign.gz -c $d\_Input_Rep0.tagAlign.gz -g dm --to-large --nomodel --shiftsize \$ss -p 0.1 -n $IPs[$i].pr2_VS_$d\_Input_Rep0 &
			wait \$!
			\n";
	}
	print OUT2 "perl $Config{'bin_dir'}/remove_1strow_encodepeak.pl ./ ./\n\n";
	for(my$i=0;$i<@IPs;$i++){
		#changed by Padma: to have consistent rep numbers between log and config file
		#my$rep1=$i+1;
		
		
		my@repname=split('Rep',$IPs[$i]);

		#number following 'Rep'
		my$rep1=$repname[-1];

		print OUT2 "# consistency: self-pesduoreplicates $IPs[$i]
		$R3_0dir/Rscript batch-consistency-analysis.r $IPs[$i].pr1.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz $IPs[$i].pr2.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz -1 $IPs[$i].pr1_VS_$IPs[$i].pr2 0 F signal.value 
		$R3_0dir/Rscript batch-consistency-plot.r 1 $IPs[$i].pr1_VS_$IPs[$i].pr2 $IPs[$i].pr1_VS_$IPs[$i].pr2
		numPeaks_Rep$rep1\_pr=\$(awk '\$11 <= $IDR_pr {print \$0}' $IPs[$i].pr1_VS_$IPs[$i].pr2-overlapped-peaks.txt | wc -l)
#		echo \"MSG: numPeaks_Rep$rep1\_pr \$numPeaks_Rep$rep1\_pr\"

		sort -k 8nr,8nr $IPs[$i].pr1_VS_$d\_Input_Rep0_peaks.encodePeak | head -n 30000 > $IPs[$i].pr1_VS_$d\_Input_Rep0_peaks.sorted.encodePeak &
		sort -k 8nr,8nr $IPs[$i].pr2_VS_$d\_Input_Rep0_peaks.encodePeak | head -n 30000 > $IPs[$i].pr2_VS_$d\_Input_Rep0_peaks.sorted.encodePeak &
		wait \$!
		$R3_0dir/Rscript batch-consistency-analysis.r $IPs[$i].pr1_VS_$d\_Input_Rep0_peaks.sorted.encodePeak $IPs[$i].pr2_VS_$d\_Input_Rep0_peaks.sorted.encodePeak -1 $IPs[$i].pr1_VS_$IPs[$i].pr2.macs 0 F p.value
		$R3_0dir/Rscript batch-consistency-plot.r 1 $IPs[$i].pr1_VS_$IPs[$i].pr2.macs $IPs[$i].pr1_VS_$IPs[$i].pr2.macs
		numPeaks_Rep$rep1\_pr_macs2=\$(awk '\$11 <= $IDR_pr {print \$0}' $IPs[$i].pr1_VS_$IPs[$i].pr2.macs-overlapped-peaks.txt | wc -l)
		echo \"MSG: numPeaks_Rep$rep1\_pr \$numPeaks_Rep$rep1\_pr \$numPeaks_Rep$rep1\_pr_macs2\"
		\n";
		print OUT3 "numPeaks_Rep$rep1\_pr=\$(awk '\$11 <= $IDR_pr {print \$0}' $IPs[$i].pr1_VS_$IPs[$i].pr2-overlapped-peaks.txt | wc -l)
#		echo \"numPeaks_Rep$rep1\_pr\t\$numPeaks_Rep$rep1\_pr\"
		numPeaks_Rep$rep1\_pr_macs2=\$(awk '\$11 <= $IDR_pr {print \$0}' $IPs[$i].pr1_VS_$IPs[$i].pr2.macs-overlapped-peaks.txt | wc -l)
		echo \"numPeaks_Rep$rep1\_pr\t\$numPeaks_Rep$rep1\_pr\t\$numPeaks_Rep$rep1\_pr_macs2\"
		\n";
		for(my$j=$i+1;$j<@IPs;$j++){
			#my$rep2=$j+1;
			
			my@repname2=split('Rep',$IPs[$j]);

               		#number following 'Rep'
                	my$rep2=$repname2[-1];

			print OUT2 "# consistency: original replicates $IPs[$i] and $IPs[$j]
				$R3_0dir/Rscript batch-consistency-analysis.r $IPs[$i].tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz $IPs[$j].tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz -1 $IPs[$i]_VS_$IPs[$j] 0 F signal.value 
				numPeaks_Rep$rep1\_Rep$rep2=\$(awk '\$11 <= $IDR_true {print \$0}' $IPs[$i]_VS_$IPs[$j]-overlapped-peaks.txt | wc -l)
#				echo \"MSG: numPeaks_Rep$rep1\_Rep$rep2 \$numPeaks_Rep$rep1\_Rep$rep2\"
				if [ \$numPeaks_Rep$rep1\_Rep$rep2 -gt \$max_numPeaks_Rep ]; then
					max_numPeaks_Rep=\$numPeaks_Rep$rep1\_Rep$rep2
				fi

				sort -k 8nr,8nr $IPs[$i]_VS_$d\_Input_Rep0_peaks.encodePeak | head -n 30000 > $IPs[$i]_VS_$d\_Input_Rep0_peaks.sorted.encodePeak &
				sort -k 8nr,8nr $IPs[$j]_VS_$d\_Input_Rep0_peaks.encodePeak | head -n 30000 > $IPs[$j]_VS_$d\_Input_Rep0_peaks.sorted.encodePeak &
				wait \$!
				$R3_0dir/Rscript batch-consistency-analysis.r $IPs[$i]_VS_$d\_Input_Rep0_peaks.sorted.encodePeak $IPs[$j]_VS_$d\_Input_Rep0_peaks.sorted.encodePeak -1 $IPs[$i]_VS_$IPs[$j].macs 0 F p.value
				numPeaks_Rep$rep1\_Rep$rep2\_macs2=\$(awk '\$11 <= $IDR_true {print \$0}' $IPs[$i]_VS_$IPs[$j].macs-overlapped-peaks.txt | wc -l)
				echo \"MSG: numPeaks_Rep$rep1\_Rep$rep2\ \$numPeaks_Rep$rep1\_Rep$rep2 \$numPeaks_Rep$rep1\_Rep$rep2\_macs2\"
				if [ \$numPeaks_Rep$rep1\_Rep$rep2\_macs2 -gt \$max_numPeaks_Rep_macs2 ]; then
					max_numPeaks_Rep_macs2=\$numPeaks_Rep$rep1\_Rep$rep2\_macs2
				fi
				\n";
			print OUT3 "
				numPeaks_Rep$rep1\_Rep$rep2=\$(awk '\$11 <= $IDR_true {print \$0}' $IPs[$i]_VS_$IPs[$j]-overlapped-peaks.txt | wc -l)
#				echo \"numPeaks_Rep$rep1\_Rep$rep2\t\$numPeaks_Rep$rep1\_Rep$rep2\"
				if [ \$numPeaks_Rep$rep1\_Rep$rep2 -gt \$max_numPeaks_Rep ]; then
					max_numPeaks_Rep=\$numPeaks_Rep$rep1\_Rep$rep2
				fi
				numPeaks_Rep$rep1\_Rep$rep2\_macs2=\$(awk '\$11 <= $IDR_true {print \$0}' $IPs[$i]_VS_$IPs[$j].macs-overlapped-peaks.txt | wc -l)
				echo \"numPeaks_Rep$rep1\_Rep$rep2\\t\$numPeaks_Rep$rep1\_Rep$rep2\t\$numPeaks_Rep$rep1\_Rep$rep2\_macs2\"
				if [ \$numPeaks_Rep$rep1\_Rep$rep2\_macs2 -gt \$max_numPeaks_Rep_macs2 ]; then
					max_numPeaks_Rep_macs2=\$numPeaks_Rep$rep1\_Rep$rep2\_macs2
				fi
				\n";
			push(@IDR_pairs,"$IPs[$i]_VS_$IPs[$j]");
			push(@IDR_pairs_macs,"$IPs[$i]_VS_$IPs[$j].macs");
		}
	}
	if (@IPs==1) {
		print OUT2 "# one replicate, no consistency analysis for original replicates
			max_numPeaks_Rep=0
			max_numPeaks_Rep_macs2=0
			\n";
	}else{
	my$pair_num=@IDR_pairs;
	print OUT2 "$R3_0dir/Rscript batch-consistency-plot.r $pair_num $d\_IP ".join(" ",@IDR_pairs)."\n";
	print OUT2 "$R3_0dir/Rscript batch-consistency-plot.r $pair_num $d\_IP.macs ".join(" ",@IDR_pairs_macs)."\n\n";
	}

	print OUT2 "# peak calls: pooled
		$R3_0dir/Rscript $Config{'bin_dir'}/run_spp.wig.R -c=$d\_IP_Rep0.tagAlign.gz -i=$d\_Input_Rep0.tagAlign.gz -npeak=$npeaks -tmpdir=./tmpspp  -odir=./   -p=$node -savr  -savp -rf -out=$Config{'date'}.cc
		
		gzip -cdf $d\_IP_Rep0.tagAlign.gz > $d\_IP_Rep0.tagAlign    
                $R2_15dir/Rscript $bin_dir/spp_wig_tagAlign.R  --args  --baseDir=./ --outDir=./ --factor=\"$d\_IP_Rep0.tagAlign\" --ipFile=$d\_IP_Rep0.tagAlign
		ss=\$(cat $Config{'date'}.cc | grep $d\_IP_Rep0.tagAlign.gz | cut -f3 |head -n 1| cut -d \",\" -f1)
		macs2 callpeak -t $d\_IP_Rep0.tagAlign.gz -c $d\_Input_Rep0.tagAlign.gz -g dm --to-large --nomodel --shiftsize \$ss -p 0.1 -n $d\_IP_Rep0_VS_$d\_Input_Rep0 &
		\n";

	print OUT2 "# call individual normalized wig for Input_R0
                $R2_15dir/Rscript $bin_dir/spp_wig_BAM.R  --args  --baseDir=./ --outDir=./ --factor=$d\_Input_Rep0 --ipFile=$d\_Input_Rep0.bam
                \n\n";
	#print OUT2 "# wig calls: input
	#	$R3_0dir/Rscript $Config{'bin_dir'}/spp_for_wig_generation_for_ct_BAM.R --baseDir=$out_dir/processing/$Config{'date'}/ --outDir=$out_dir/processing/$Config{'date'} --factor=$d\_Input_Rep0 --ipFile=$d\_Input_Rep0.bam
	#	\n";

	print OUT2 "# peak calls: pooled-pseduoreplicates
		$R3_0dir/Rscript $Config{'bin_dir'}//run_spp.R -c=$d\_IP_Rep0.pr1.tagAlign.gz -i=$d\_Input_Rep0.tagAlign.gz -npeak=$npeaks -tmpdir=./tmpspp  -odir=./   -p=$node -savr  -savp -rf -out=$Config{'date'}.cc
		ss=\$(cat $Config{'date'}.cc | grep $d\_IP_Rep0.pr1.tagAlign.gz | cut -f3 | head -n 1 | cut -d \",\" -f1)
		macs2 callpeak -t $d\_IP_Rep0.pr1.tagAlign.gz -c $d\_Input_Rep0.tagAlign.gz -g dm --to-large --nomodel --shiftsize \$ss -p 0.1 -n $d\_IP_Rep0.pr1_VS_$d\_Input_Rep0 &
		$R3_0dir/Rscript $Config{'bin_dir'}//run_spp.R -c=$d\_IP_Rep0.pr2.tagAlign.gz -i=$d\_Input_Rep0.tagAlign.gz -npeak=$npeaks -tmpdir=./tmpspp  -odir=./   -p=$node -savr  -savp -rf -out=$Config{'date'}.cc
		ss=\$(cat $Config{'date'}.cc | grep $d\_IP_Rep0.pr2.tagAlign.gz | cut -f3 | head -n 1 | cut -d \",\" -f1)
		macs2 callpeak -t $d\_IP_Rep0.pr2.tagAlign.gz -c $d\_Input_Rep0.tagAlign.gz -g dm --to-large --nomodel --shiftsize \$ss -p 0.1 -n $d\_IP_Rep0.pr2_VS_$d\_Input_Rep0 &
		wait \$!
		";
	print OUT2 "perl $Config{'bin_dir'}/remove_1strow_encodepeak.pl ./ ./\n\n";
	print OUT2 "# consistency: pooled-pseduoreplicates
		$R3_0dir/Rscript batch-consistency-analysis.r $d\_IP_Rep0.pr1.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz $d\_IP_Rep0.pr2.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz -1 $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2 0 F signal.value
		$R3_0dir/Rscript batch-consistency-plot.r 1 $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2 $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2
		numPeaks_Rep0_pr=\$(awk '\$11 <= $IDR_pr {print \$0}' $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2-overlapped-peaks.txt | wc -l)
#		echo \"MSG: numPeaks_Rep0_pr \$numPeaks_Rep0_pr\"
		if [ \$numPeaks_Rep0_pr -gt \$max_numPeaks_Rep ]; then
			optThresh=\$numPeaks_Rep0_pr
		else
			optThresh=\$max_numPeaks_Rep
		fi
#		echo \"MSG: optThresh \$optThresh\"
		zcat $d\_IP_Rep0.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz | sort -k7nr,7nr | head -n \$optThresh | gzip -c > spp.optimal.$d\_IP_Rep0.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz
#		echo \"MSG: conThresh \$max_numPeaks_Rep\"
		zcat $d\_IP_Rep0.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz | sort -k7nr,7nr | head -n \$max_numPeaks_Rep | gzip -c > spp.conservative.$d\_IP_Rep0.tagAlign_VS_$d\_Input_Rep0.tagAlign.regionPeak.gz

		sort -k 8nr,8nr $d\_IP_Rep0.pr1_VS_$d\_Input_Rep0_peaks.encodePeak | head -n 30000 > $d\_IP_Rep0.pr1_VS_$d\_Input_Rep0_peaks.sorted.encodePeak &
		sort -k 8nr,8nr $d\_IP_Rep0.pr2_VS_$d\_Input_Rep0_peaks.encodePeak | head -n 30000 > $d\_IP_Rep0.pr2_VS_$d\_Input_Rep0_peaks.sorted.encodePeak &
		wait
		$R3_0dir/Rscript batch-consistency-analysis.r $d\_IP_Rep0.pr1_VS_$d\_Input_Rep0_peaks.sorted.encodePeak $d\_IP_Rep0.pr2_VS_$d\_Input_Rep0_peaks.sorted.encodePeak -1 $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2.macs 0 F p.value
		$R3_0dir/Rscript batch-consistency-plot.r 1 $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2.macs $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2.macs
		numPeaks_Rep0_pr_macs2=\$(awk '\$11 <= $IDR_pr {print \$0}' $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2.macs-overlapped-peaks.txt | wc -l)
		echo \"MSG: numPeaks_Rep0_pr \$numPeaks_Rep0_pr \$numPeaks_Rep0_pr_macs2\"
		if [ \$numPeaks_Rep0_pr_macs2 -gt \$max_numPeaks_Rep_macs2 ]; then
			optThresh_macs2=\$numPeaks_Rep0_pr_macs2
		else
			optThresh_macs2=\$max_numPeaks_Rep_macs2
		fi
		echo \"MSG: optThresh \$optThresh \$optThresh_macs2\"
		cat $d\_IP_Rep0_VS_$d\_Input_Rep0_peaks.encodePeak | sort -k 8nr,8nr | head -n \$optThresh_macs2 | gzip -c > macs.optimal.$d\_IP_Rep0_VS_$d\_Input_Rep0_peaks.encodePeak.gz
		echo \"MSG: conThresh \$max_numPeaks_Rep \$max_numPeaks_Rep_macs2\"
		cat $d\_IP_Rep0_VS_$d\_Input_Rep0_peaks.encodePeak | sort -k 8nr,8nr | head -n \$max_numPeaks_Rep_macs2 | gzip -c > macs.conservative.$d\_IP_Rep0_VS_$d\_Input_Rep0_peaks.encodePeak.gz
		\n\n";
	print OUT3 "
		numPeaks_Rep0_pr=\$(awk '\$11 <= $IDR_pr {print \$0}' $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2-overlapped-peaks.txt | wc -l)
#		echo \"numPeaks_Rep0_pr\t\$numPeaks_Rep0_pr\"
		if [ \$numPeaks_Rep0_pr -gt \$max_numPeaks_Rep ]; then
			optThresh=\$numPeaks_Rep0_pr
		else
			optThresh=\$max_numPeaks_Rep
		fi
#		echo \"optThresh\t\$optThresh\"
#		echo \"conThresh\t\$max_numPeaks_Rep\"

		numPeaks_Rep0_pr_macs2=\$(awk '\$11 <= $IDR_pr {print \$0}' $d\_IP_Rep0.pr1_VS_$d\_IP_Rep0.pr2.macs-overlapped-peaks.txt | wc -l)
		echo \"numPeaks_Rep0_pr\t\$numPeaks_Rep0_pr\t\$numPeaks_Rep0_pr_macs2\"
		if [ \$numPeaks_Rep0_pr_macs2 -gt \$max_numPeaks_Rep_macs2 ]; then
			optThresh_macs2=\$numPeaks_Rep0_pr_macs2
		else
			optThresh_macs2=\$max_numPeaks_Rep_macs2
		fi
		echo \"optThresh\t\$optThresh\t\$optThresh_macs2\"
		echo \"conThresh\t\$max_numPeaks_Rep\t\$max_numPeaks_Rep_macs2\"
		\n\n";
}

print OUT1 "### move to the processing/DATE/ directory and run the main script
#cd $Config{'out_dir'}/processing/$Config{'date'}/
#sh run_$Config{'date'}.sh
";
print OUT2 "### move wiggle files to subdirectory
mkdir wig/
mv *.wig wig/

### generate IDR report
sh report_$Config{'date'}.sh > $Config{'sp'}_idr_$Config{'date'}.log
\n";

print OUT2 "### generate bed files for SPP peak calls
mkdir bed/
ls *regionPeak.gz > regionPeak.list
while read -r line
do
zcat \$line | cut -f1-3 > \$line.bed33
done < regionPeak.list
mv *regionPeak.gz.bed33 bed/
rename s/regionPeak.gz.bed33/bed/ bed/*
\n";

print OUT2 "### remove 50% overlapping peaks from blacklist
ls spp.*.regionPeak.gz  > spp.list
while read -r line
do
bedtools intersect -a \$line -b $bin_dir/blacklist/$black_list  -f 0.5 -v > \$line.rmblacklist
done < spp.list
rename s/regionPeak.gz.rmblacklist/regionPeak.rmblacklist/ *.regionPeak.gz.rmblacklist
\n";

print OUT2 "##remove spp temp dir
rm ./tmpspp/*.*
rmdir tmpspp
\n";

close OUT1;
close OUT2;
close OUT3;

Ptime("Done!");

