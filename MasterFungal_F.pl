#!usr/bin/perl
use warnings;
use strict;

#This one boils down the output from E into something more useful: a table of individuals 

# perl /home/nick/perl_tools/MasterFungal_F.pl -I order_summary22 -I order_summary1 -I order_summary3 -I order_summary2 -I order_summary4 -I chinese_orders -I chinese_orders2 -I families_ulmus -I families_juglans -T genera_family_order.csv -O order_table 
my @commands = @ARGV;
my @inputs; 
my $output;
my $table;

for (my $i = 0; $i < @commands; $i++ ){
	#print "command: $commands[$i]\n";
	if ($commands[$i] =~ /-I/){ push @inputs, $commands[$i+1];}
	if ($commands[$i] =~ /-O/){ $output = $commands[$i+1];}
	if ($commands[$i] =~ /-T/){ $table = $commands[$i+1];}
}

#Goals: take the set of input files, which are tables formatted like this 
#Infile: sample.txt
#Ascomycota:Pleosporales	1000
#Ascomycota:Capnodiales	990	

#Etc. What we want is a table formatted like this
#taxon	sample1.txt	sample2.txt	
#Pleos.	1000	500		
#
#
#The program first read the table for the list of potential fungi

open my $gen_in, "<", "$table";

my %orders;
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
		$orders{$order} = 0;
	}
}

#Next iterate through the input files

my %all_values;

foreach my $inputs (@inputs) {
	open my $in, "<", "$inputs" or die "Could not open file $inputs!\n";
	my $current_sample;
	while (my $line = <$in>){
		chomp $line;
		if ($line =~ /\.txt/){
			$current_sample = $line;
		}
		else {
			my @parts = split ('	' ,$line);
			my $count = $parts[1];
			my $key = $parts[0];
			$all_values{$current_sample}{$key} = $count;
			print "sample = $current_sample; key = $key; count = $count\n";}
	}
}
sleep 10;
open my $out, ">", "$output";

#Now iterate through the hash to print everything
print $out "Taxa	";

foreach my $samples (sort keys %all_values){
	print $out "$samples	";}
print $out "\n";

#done printing headers
foreach my $taxa (sort keys %orders){
	#print the taxon name
	print $out "$taxa	";
	foreach my $samples (sort keys %all_values){		
		my $ref = $all_values{$samples};
		my %sample_hash = %$ref;
		if (exists $sample_hash{$taxa}){
			print $out "$sample_hash{$taxa}	";}
		else { print $out "0	"};
	}						
	print $out "\n";
}

