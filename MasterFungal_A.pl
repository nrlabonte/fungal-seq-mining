#!usr/bin/perl
use warnings;
use strict;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;

#This program reads the BLAST-tab formatted output from DIAMOND aligner
#Uses a file of fungal taxonomic codes to describe taxonomy of each hit
#Extracts sequences from the original FASTQ file submitted to DIAMOND
#Uses DIAMOND to align extracted sequences to the NR database

#Hit files are BLAST-tab formatted outputs from diamond


#First input: hit files (-H)
#print "Enter path/name of hit files to use.  If multiple, separate with commas:\n";
##ONLY USE ONE AT A TIME
#my $hit_in = <>;
#chomp $hit_in;
#my @hit_in = split (',', $hit_in);

#Second input: taxonomy file (-T)

#Third input: FASTQ file corresponding to hit files (use same order!) (-F)

#Fourth input: path to nr database in dmnd format (-D)

#Fifth input: path to DIAMOND aligner (-A)

#Sixth input: path to output prefix (-O)

#example command: perl ./master_fungal.pl --H sample1_hits.txt --H sample2_hits.txt --T taxonomy.txt --F s1reads.fastq.gz s2reads.fastq.gz --D /diamond/nr --A /diamond/diamond.exe -O /home/out/out 

#Step 1. Parse input line 

#print "Submit command entry:\n";

my @command = @ARGV;

my @HitFiles;
my $TaxaFile;
my @FastQs;
my $DataBase;
my $Aligner;
my $Out;
my $NCBI_Path;

#print "Option to skip steps for partially completed jobs.\n";
#print "1	Skip Fastq processing\n2	Skip BLASTx search of nr database\n3	Skip the taxonomic report\n9	Do not skip anything\n";

#my $options = <>;
#chomp $options;

foreach (my $i = 0; $i < @command; $i++){
	print "command entry : $command[$i]\n";
	if ($command[$i] =~ /-H/){
	push(@HitFiles, $command[$i+1]);
	print "Found hit file $command[$i]\n";
	}
	if ($command[$i] =~ /-T/){
	$TaxaFile = $command[$i+1];
	#print "Found taxa\n";
	}
	if ($command[$i] =~ /-F/){
	push(@FastQs, $command[$i+1]);
	#print "Found Fastqs\n";
	}
	if ($command[$i] =~ /-D/){
	$DataBase = $command[$i+1];
	#print "Found database\n";
	}
	if ($command[$i] =~ /-A/){
	$Aligner = $command[$i+1];
	print "Found aligner\n";
	}
	if ($command[$i] =~ /-O/){
	$Out = $command[$i+1];
	print "Found output prefix\n";
	}
}
my %uniq_seq;
#my @unique_names;
##First... read the hitfile into a hash of unique sequence identifiers	
foreach my $hitfile (@HitFiles){
	print "Opening hit file $hitfile \n";
	open my $hit_file, "<", "$hitfile" or die "Unable to open hit file.\n";
	
	#Parser needs to: 
	#1. Find and keep unique IDs of sequences
	#2. Store them in an array 
	my $uniq_counter = 0;
	my $prev_name = "empty";
	my $lines = 0;
	while (my $line = <$hit_file>){
		(my $name, my @other)  = split (/\s/, $line);
		if ($name !~ m/$prev_name/){
			#push (@unique_names, $name);
			$uniq_seq{$name} = $other[0];
			#Print statement
			if ($uniq_counter%100000 == 0){print "Processed $uniq_counter sequences.\n";}
			$uniq_counter++;
			$prev_name = $name;
		}
		$lines++;	
	}
	print "$uniq_counter unique reads out of: $lines\n";
}

##Second... extract the actual sequences from the FASTQ file using a hash and send to an intermediate Fasta file
my $fq = $FastQs[0];
my $fq_suffix = "hitseqs.fasta";
my @fq_names = split(/\./, $fq);
my $fq_prefix = $fq_names[0]; 	
my $outfile = join('_', $fq_prefix, $fq_suffix); 
chomp $outfile;
print "Outfile name: $outfile\n";
	
foreach my $fastq (@FastQs){
	#open my $fastq, "<", "$fastq_in" or die "Unable to open FASTQ file.\n";
	print "Name of fastq: $fastq\n ";
	my $z = new IO::Uncompress::Gunzip $fastq or die "gunzip failed: $GunzipError\n";
	
	open (my $fh, '>', $outfile) or die "Could not open outfile. Sorry!\n";
	my @temp_array;
	my $counter = 0;
	my $counter2 = 0;
	while (my $row = <$z>){
		chomp $row;
		if ($row =~ m/HWI-ST1234:/){
			my $rowa = substr $row, 1;
			(my $keep, my $tail) = split (/\s/, $rowa);
			$temp_array[0] = $keep;
			#if ($counter%500000==0){print "head=$keep\n";}
			$counter++;
			}
		if (($row =~ m/[ATGC]/) && ($row !~ m/[FHJIDE]/)){
			$temp_array[1] = $row;
			}
		if ($row =~ m/^\+/){
		my $head = $temp_array[0];
		my $match = 0;
		if (exists $uniq_seq{$head}){
			#print "Found one!\n";
			print $fh ">$temp_array[0]\n$temp_array[1]\n";
		}
		#if (($uniq_seq{$head}==0) && ($counter%100000 == 0)){
		#	print "nothing here...\n";
		#}
		}	
		if ($counter%1000000 == 0){
			print "Processed $counter reads\n";
		}
	}
}
##Third... submit the reduced FASTa (of "fungal hit" sequences) to a search of nr using Diamond
#needed: fasta output, database, output prefix
print "outfile name : $outfile\n";
my @diamond_com;
$diamond_com[0] = "$Aligner";
$diamond_com[1] = "blastx -q";
$diamond_com[2] = $outfile;
$diamond_com[3] = "-d";
$diamond_com[4] = $DataBase;
$diamond_com[5] = "-a";
my $nr_out_suffix = "nr_out";
$diamond_com[6] = $Out.$nr_out_suffix;
$diamond_com[7] = "-t /media/nick/My_Book/";

my $diamond_command = join(' ', @diamond_com);

system($diamond_command);

if ( $? == -1 )
{
  print "command failed: $!\n";
}
else
{
  printf "command exited with value %d", $? >> 8;
}

my @dia_com2;

$dia_com2[0] = $Aligner;
$dia_com2[1] = "view -a"; 
#my $daa = ".daa";
my $other_out = $diamond_com[6];
$dia_com2[2] = $other_out;
$dia_com2[3] = "-o";
my $nr_tab_suffix = "_nr_out.txt";
$dia_com2[4] = $Out.$nr_tab_suffix;
my $dia_com_2 = join(' ', @dia_com2);

print "Preparing to submit DIAMOND command.\n";
system($dia_com_2);

if ( $? == -1 )
{
  print "command failed: $!\n";
}
else
{
  printf "command exited with value %d", $? >> 8;
}
