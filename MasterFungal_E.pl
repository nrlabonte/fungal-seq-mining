#!usr/bin/perl
use warnings;
use strict;

#MasterFungal_E.pl

#The lastest installation in the Master_fungal series, this script:
#uses the output from the MF-D.pl and a csv of fungal genus-order tables to make a summary of which orders are best-represented in the data.  

#Sample line of commands
# perl MasterFungal_E.pl -I home/nick/Documents/fungal_results/juglans_fungal_genera -T /home/nick/Documents/fungal_results/genera_family_order.csv -O /home/nick/Documents/fungal_results/families_juglans


my @commands = @ARGV;
my @inputs;
my $output;
my $input; 
my $table; 

for (my $i = 0; $i < @commands; $i++ ){
	#print "command: $commands[$i]\n";
	if ($commands[$i] =~ /-I/){ $input = $commands[$i+1];}
	if ($commands[$i] =~ /-O/){ $output = $commands[$i+1];}
	if ($commands[$i] =~ /-T/){ $table = $commands[$i+1];}
}


#read in table of genera to hash 
#$genera{genus} => order;

open my $gen_in, "<", "$table";

my %genera;
my $current_group;
while (my $line = <$gen_in>){
	chomp $line;
	if ($line =~ /#/){
		$current_group = $line;
		$current_group =~ s/#//;}
	else {
		my @parts = split ',', $line;
		my $genus = $parts[0];
		my $order = join ('', $current_group, $parts[1]);
		$genera{$genus} = $order;
	}
}

#read in the genus report for each sample
#Multiple samples are contained in one file.  A new sample is signaled with an Infile: header.  
my %order_sums;
my $current_sample; #derive this by splitting on fwd-slash (2nd part)
my $sample_counter = 0;
my $unknown_key = "Ungrouped"; #this is need for genera I did not bother to look up
#$order_sums{order} => genus1 + genus 2 etc. 
#need to print order sums when $current_sample is updated

open my $report_in, "<", "$input";
open my $fh_out, ">", "$output";

while (my $line = <$report_in>){
	chomp $line;
	if ($line =~ /count/){
		next;}
	if ($line =~ /Infile:/){
		my @parts = split (/\//, $line);
		if ($sample_counter != 0){
				print $fh_out "$current_sample\n";
			foreach my $orders (sort keys %order_sums){
				print $fh_out "$orders	$order_sums{$orders}\n";}
		}
		$sample_counter++;
		%order_sums = ();
		$current_sample = $parts[1];	
	}
	else {
		my @parts = split('	', $line);
		my $genus = $parts[0];
		my $total = $parts[1];
		if (exists $genera{$genus}){
		
			my $order = $genera{$genus};
				print "genus = $genus; total = $total; order = $order\n";
			if (exists $order_sums{$order}){
				$order_sums{$order} = $order_sums{$order} + $total;
				print "Added total to order $order.\n";}
			else { $order_sums{$order} = $total;
				print "Added $order to hash\n";}
		}
		else {print "Genus $genus not found in family table!\n";}
	}
}

print $fh_out "$current_sample\n";
foreach my $orders (sort keys %order_sums){
	print $fh_out "$orders	$order_sums{$orders}\n";}
