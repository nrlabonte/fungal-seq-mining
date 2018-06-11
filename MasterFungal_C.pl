#!usr/bin/perl
use warnings;
use strict;

#Goal: Output a summary of basidio vs. asco sequences, most commonly seen ascomycetes vs. basidiomycetes, etc
#need to make: array of "seen" ascomycetes; basidiomycetes; etc. 
#Hash of all sequences key'ed by top hit species
#Hash of all seqs. key'ed by 2nd hit, third hit... so output will be
#Header line with summary
# num. ascomycetes, num. basidiomycetes, num. zygomycetes, num. unclassified (majority)
#species name

#This takes, as input, the output from MasterFungal_B.pl, which generates a list of reads ID'ed as fungal, with the top few hits for each sequence.  

# perl MasterFungal_C.pl -I report.txt -O output.txt

my @commands = @ARGV;
my @infiles;
my $Out1;
for(my $i=0; $i<@commands; $i++){
	if ($commands[$i] =~/-I/) { push @infiles, $commands[$i+1]; } 
	if ($commands[$i] =~/-O/) { $Out1 = $commands[$i+1]; }
}

foreach my $reportin_f (@infiles)
{
	open my $report_in, "<", "$reportin_f" or die "Unable to open the full report file.\n";

	#Hash stores %seen_spp{$species} = # of times seen
	my %seen_spp;

	#Stores %top_x{$species} = # of times seen as a top hit
	my %top_ascos; 
	my %top_basidios;
	my %top_mucos;
	my %top_other;

	#This stores the line with the read name and top hit
	my $id_line;
	#This stores the line with the next few hits
	my $species_line; 
	
	#Initializes counters for each taxon
	my $ac = 0;
	my $bc = 0;
	my $mc = 0;
	my $fc = 0;

	
	while (my $line = <$report_in>)
	{	
		chomp $line;
		my @species_array;
		#Pull out taxonomic ID
		if ($line =~ /seq:/)
		{
			#Identifies the line with the sequence name, classification, and top hit
			$id_line = $line;
			my ($sequence_name, $taxon, $top_hit) = split(/	/, $line);
			if ($taxon =~ m/asco/)
			{
				$ac++;
				if (exists $top_ascos{$top_hit})
				{
					$top_ascos{$top_hit}++;
				}
				else 
				{
					$top_ascos{$top_hit} = 1;
				}
			}
			if ($taxon =~ m/basidio/)
			{
				$bc++;
				if (exists $top_basidios{$top_hit})
				{
					$top_basidios{$top_hit}++;
				}
				else 
				{
					$top_basidios{$top_hit} = 1;
				}
			}
			if ($taxon =~ m/muco/)
			{
				$mc++;
				if (exists $top_mucos{$top_hit})
				{
					$top_mucos{$top_hit}++;
				}
				else 
				{
					$top_mucos{$top_hit} = 1;
				}
			}
			if ($taxon =~ m/fungi/)
			{
				$fc++;
				if (exists $top_other{$top_hit})
				{
					$top_other{$top_hit}++;
				}
				else 
				{
					$top_other{$top_hit} = 1;
				}
			}
			
		}
		else
		{
			$species_line = $line;
			@species_array = split(/	/, $line);
			foreach my $species (@species_array)
			{
				if (exists $seen_spp{$species})
				{
					$seen_spp{$species}++;
				}
				else
				{
					$seen_spp{$species} = 1;
				}
			}


		}
	}

	print "Summary report for $reportin_f\n";
	print "asco: $ac basidio: $bc muco: $mc nongrouped: $fc\n";

	my $reduced_out = "_species_summary.txt";
	my $report_out = $Out1.$reduced_out;

	open (my $report_fh, ">", "$report_out") or die "Could not open report out file!\n";

	print $report_fh "#Species	#Times_Seen\n";
	foreach my $sp (keys %seen_spp)
	{
		print $report_fh "$sp	$seen_spp{$sp}\n";
	}

	print $report_fh "#Top ascomycetes\n#Species	#Times_top_hit\n";
	foreach my $asco (keys %top_ascos)
	{
		print $report_fh "$asco	$top_ascos{$asco}\n";
	}
	print $report_fh "#Top basidiomycetes\n#Species	#Times_top_hit\n";
	foreach my $ba (keys %top_basidios)	
	{
		print $report_fh "$ba	$top_basidios{$ba}\n";
	}
	print $report_fh "#Top mucoromycetes\n#Species	#Times_top_hit\n";
	foreach my $mu (keys %top_mucos)
	{
		print $report_fh "$mu	$top_mucos{$mu}\n";
	}
	print $report_fh "#Top unclassified fungi\n#Species	#Times_top_hit\n";
	foreach my $fun (keys %top_other)
	{
		print $report_fh "$fun	$top_other{$fun}\n";
	}
}
