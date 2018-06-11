#!usr/bin/perl
use warnings;
use strict;

#Summarizes top genera from the output of Master_Fungal_C
# -I masterC_out.txt output from previous step in chain; can pass multiples
# -O output txt file
#
#perl /home/nick/perl_tools/MasterFungal_D.pl -I fungal_results/ecc01fungal_species_summary.txt -I fungal_results/ecc02fungal_species_summary.txt -I fungal_results/ecc03fungal_species_summary.txt -I fungal_results/ecc06fungal_species_summary.txt -I fungal_results/ecc12fungal_species_summary.txt -I fungal_results/ecc16fungal_species_summary.txt -I fungal_results/ecc20fungal_species_summary.txt -I fungal_results/ecc23fungal_species_summary.txt -I fungal_results/ecc24fungal_species_summary.txt -I fungal_results/ecc27fungal_species_summary.txt  -I fungal_results/ecc28fungal_species_summary.txt -I fungal_results/iac01fungal_species_summary.txt -I fungal_results/iac02fungal_species_summary.txt -O fungal_results/genus_summary_1.txt

my @commands = @ARGV;
my @inputs;
my $output;
for (my $i = 0; $i < @commands; $i++ ){
	#print "command: $commands[$i]\n";
	if ($commands[$i] =~ /-I/){ push @inputs, $commands[$i+1];}
	if ($commands[$i] =~ /-O/){ $output = $commands[$i+1];}
}

open my $outf, ">", "$output" or die "Couldn't open that output\n";

foreach my $input (@inputs){
	my %aseen;
	my %asco_genera;
	my $asco_flag = 0;
	my %bseen;
	my %basidio_genera;
	my $basidio_flag = 0;
	my %ano_names;
	my %bno_names;
	open my $inf, "<", "$input" or die "Couldn't open that input: $input\n";
	while (my $line = <$inf>){
		chomp $line;
		if ($line =~ /#Top basidiomycetes/){
			$basidio_flag = 1;
			$asco_flag = 0;
		}
		if ($line =~ /#Top ascomycetes/){
			#print "Found start of asco entries\n";
			$basidio_flag = 0;
			$asco_flag = 1;
		}
		if ($line =~ /#Top muco/){
			$basidio_flag = 0;
			$asco_flag = 0;
		}
		#print "asco line: $line\n";
		my @parts1 = split('	', $line);
		my $taxon = $parts1[0];
		my $count = $parts1[1];
		my @parts2 = split ('_', $taxon);
		my $num = $parts2[0];
		my $species = $parts2[1];
		#print "broken line: num $num species $species count $count \n";
		if ($asco_flag == 1){
			if ($species){ #only execute if there are words in the species entry
				my @species_elements = split( /\s/, $species);
				my $genus = $species_elements[0];
				if (exists $asco_genera{$genus}){
					$asco_genera{$genus} = $asco_genera{$genus} + $count;}
				else {
					$asco_genera{$genus} = $count;}
				$aseen{$num} = $genus;
			}
			else { #what to do about species that just have numbers?
				if (exists $ano_names{$num}){ $ano_names{$num} = $ano_names{$num} + $count; }
				else {$ano_names{$num} = $count;}
			}
		}
		if ($basidio_flag == 1){
			if ($species){ #only execute if there are words in the species entry
				my @species_elements = split( /\s/, $species);
				my $genus = $species_elements[0];
				if (exists $basidio_genera{$genus}){
					$basidio_genera{$genus} = $basidio_genera{$genus} + $count;}
				else {
					$basidio_genera{$genus} = $count;}
				$bseen{$num} = $genus;
			}
			else { #what to do about species that just have numbers?
				if (exists $bno_names{$num}){ $bno_names{$num} = $bno_names{$num} + $count; }
				else {$bno_names{$num} = $count;}
			}
		}
	}	
	foreach my $anon (keys %ano_names){
		if (exists $aseen{$anon}){
			my $gen = $aseen{$anon};
			$asco_genera{$gen} = $asco_genera{$gen} + $ano_names{$anon};
		}
	}
	foreach my $anon (keys %bno_names){
		if (exists $bseen{$anon}){
			my $gen = $bseen{$anon};
			$basidio_genera{$gen} = $basidio_genera{$gen} + $bno_names{$anon};
		}
	}
	print $outf "Infile: $input\n";
	print $outf "Asco_genus	count\n";
	foreach my $asco (keys %asco_genera){
		if ($asco_genera{$asco} >= 10){
			print $outf "$asco	$asco_genera{$asco}\n";}
	}
	print $outf "Basidio_genus	count\n";
	foreach my $basidio (keys %basidio_genera){
		if ($basidio_genera{$basidio} >= 10){
			print $outf "$basidio	$basidio_genera{$basidio}\n";}
	}
}




