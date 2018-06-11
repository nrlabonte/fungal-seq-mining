#!usr/bin/perl
use warnings;
use strict;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;

#Uses an input line like MasterFungal_A script

#First input: --H BLAST-tab format outpt file from the DIamond aligner
# Second --T The path to the NCBI taxonomy dump files
#Third --O the output prefix-- will have individual identifiers added to it.  
# This needs to contain the path to the taxonomy files,
# and the files that link accession numbers to taxonomic IDs.  

###########SECTION 1###############
###This section processes the tab-format BLAST output from Diamond, 
###and prepares a list of unique genbank IDs to use in later parts of the analysis.

###Open nr-BLAST-tab output file
#my $nr_outfile = $dia_com2[3];
#open (my $nr_out, "<", "$nr_outfile") or die "Could not open the blast-tab outfile from nr! Sorry!\n";

#print "Enter line of commands, separated by tabs:\n";

#my $command = <>;
#chomp $command;

my @commands = @ARGV;
my @nr_hitfiles; 
my $dmp_path;
my $Out;

#This loop identifies the different commands 
for (my $i=0;$i<@commands;$i++){
	if ($commands[$i] =~ /-H/){	
		push (@nr_hitfiles, $commands[$i+1]);}
	if ($commands[$i] =~ /-T/){
		$dmp_path = $commands[$i+1];}
	if ($commands[$i] =~ /-O/){
		$Out = $commands[$i+1];}
	}

#Load in the taxonomic information first, because this will only need to be done once. 
##Read the nodes file to store taxonomic information for available taxa
my $nodes = "nodes.dmp";
my $path_to_nodes = $dmp_path.$nodes;

open (my $nodesfile, "<", "$path_to_nodes") or die "Could not open the taxonomy nodes file! Sorry!\n";
my %accs;
my %subspp;
my %spp;
my %higher;

my $counter = 0;
while (my $line = <$nodesfile>)
{
	my @elements = split(/	\|	/, $line);
	if ($elements[2] =~ m/no rank/){
		my $acc = $elements[0];
		my $sp_parent = $elements[1];
		$accs{$acc} = $sp_parent;}
	if ($elements[2] =~ m/subspecies/){
		my $subsp = $elements[0];
		my $sp_parent = $elements[1];
		$subspp{$subsp} = $sp_parent;}
	if ($elements[2] =~ m/species/){
		my $sp = $elements[0];
		my $gen_parent = $elements[1];
		$spp{$sp} = $gen_parent;}
	else{
		my $taxon = $elements[0];
		my $parent = $elements[1];
		$higher{$taxon} = $parent;}
	$counter++;
}
	
close $nodesfile;
print "Processed $counter lines.\n";		
#Stage 2 merge the subspecies and "no rank"  into the "sp" hash

while ( my ($key, $value) = each %accs ){
	if (exists $spp{$value}){
		my $genus = $spp{$value};
		$spp{$key} = $genus;}	
}
print "done processing 'no rank' entries\n";

while ( my ($key, $value) = each %subspp ){
	if (exists $spp{$value}){
		my $genus = $spp{$value};
		$spp{$key} = $genus;}	
}	
	
print "done processing 'subsp' entries\n";

#Stage 3 build the full taxonomy for each entry in "spp"
#but only keeps plants and fungi
my %spp_full;
my $entry_counter = 0;
while ( my ($key, $value) = each %spp ){
	my $next1;
	my $taxonomy;
	if (exists $higher{$value}){
		$next1 = $higher{$value};
		$taxonomy = join("_", $next1, $value);
		#Iterates an arbitrary number of times (25) but this will get up to the top of the taxonomic tree for each entry
		for (my $i=0;$i<25;$i++){
			if (exists $higher{$next1}){
				my $add = $next1;
				$next1 = $higher{$next1};
				$taxonomy = join("_", $add, $taxonomy);}
	}	
	if (($taxonomy =~ m/_4751_/) || ($taxonomy =~ m/_3193_/)){
		$spp_full{$key} = $taxonomy;}
	}
	$entry_counter++;
	if ($entry_counter%100000 == 0) {print "Processed $entry_counter entries.\n";}
}
print "Processing of taxonomy files complete.  \n";
#NOW move on to process hitfiles.  

foreach my $nr_hits (@nr_hitfiles){
	print "Processing hit file $nr_hits.\n";
	###Initialize array to hold unique GI numbers from the output file
	###Initialize counters to keep track of how many GI numbers are being processed
	my %unique_GIs;
	my %blast_summary;
	my $unique_nums = 0;
	my $not_unique = 0;
	my $previous_name = "empty";
	my @GI_per_read;
	open my $nr_out, "<", "$nr_hits" or die "Unable to open hit file.\n";
	my $progress_meter = 0;
	my $tally = 0;
	while (my $line = <$nr_out>){
		$tally++;
		}
	print "Total number of lines in nr out file to process = $tally\n";
	open my $nr_out2, "<", "$nr_hits" or die "Unable to open hit file.\n";
	###Input loop for BLAST output
	while (my $line = <$nr_out2>){
		###Skip comments
		next if ($line =~ /^#/);
		chomp $line;
		$progress_meter++;
		###Divide query name from other information
		(my $name, my @other)  = split (/	/, $line);
		###Genbank identifier is the first part of "other"
		###Extract just the GI number
		###LATER: Change this to the accession ID number!!
			#"Name" here is the read ID number. 
		if ($previous_name =~ /empty/) {
			$previous_name = $name; }
		#If the name does not match the previous name... 
		if ($name !~ m/$previous_name/){
			#Perform actions to begin processing results for a new read...
			#First, join the array of GI numbers of the hits...		
			my $GI_for_read = join('_', @GI_per_read);
			#Put the string of identifiers into a hash with the read name as the key...
			$blast_summary{$previous_name} = $GI_for_read;
			#Reset previous name variable
			$previous_name = $name; 
			#Empty the identifier array
			@GI_per_read = ();
			}
		#Below: actions performed whether or not the previous name matches
		#Extract GI number...
		my $full_gi = $other[0];
		#Split it to just get the stuff we need... 
		my @gi_parts = split (/\|/, $full_gi);
		my $gi_num = $gi_parts[1];
		#Put it into the array with the identifiers for a given read's hits
		push (@GI_per_read, $gi_num);
		###This statement adds the GI number to the "Unique" array if it is not there yet
		###Increments a counter if the GI number is already in the array
		if (exists $unique_GIs{$gi_num}) {
			$not_unique++;} 
		else {
			$unique_GIs{$gi_num} = $full_gi;
			$unique_nums++; }
		if ($progress_meter%1000000 == 0){	
			print "Read through $progress_meter lines of $tally total lines in the NR output file.\n";}
	}
	print "Found $unique_nums unique GI numbers and $not_unique duplicates.\n";

	###########SECTION 2####################
	#This requires a series of NCBI files in the "taxdump" folder.
	###The important files here are...
	#1. A 2-column text file linking GI numbers to taxid numbers
	#2. A text file with the taxonomic tree info for each taxid
	#3. A text file with the scientific names for the taxIDs

	###A. Get the taxids for all the gi numbers in the nr hitfile	
	###Input the path to the taxdump folder
	#my $path_to_folder = $NCBI_Path;

	###Step A1. Pull out the GI numbers of all the sequences in the hit file
	my $link = "gi_taxid_prot.dmp";
	my $linkF = $dmp_path.$link;

	###Open filehandle to the full link file (two columns)
	open (my $linkFile, "<", "$linkF") or die "Could not open the taxonomy link file! Sorry!\n";
	###Loop to grab only the GIs from the nr output file processed by section 1
	my $i = 0;
	my $j = 0;
	my %GI_to_Tax;
	my %taxa_to_keep;
	while (my $line = <$linkFile>) {
		chomp $line;
		if ($line =~ /\d+/){
			my @taxIDs = split(/	/, $line);
			my $GI = $taxIDs[0];	
			if (exists $unique_GIs{$GI}) {
				my $taxID = $taxIDs[1];
				$GI_to_Tax{$GI} = $taxID;
				$taxa_to_keep{$taxID} = $GI;
				$j++;
				}
			if ($i%100000000 ==0) {print "Filtered GI-taxon link file for $i GI identifiers from hit file.\n";}
			$i++;
		}
	} 

	###B. Get real names for the taxids that we're interested in
	#read in the "names.dmp" file

	my $names = "names.dmp";
	my $namesF = $dmp_path.$names;
	open (my $namesFH, "<", "$namesF") or die "Could not open the taxonomy names file! Sorry!\n";
	#Open fh for temp. taxonomy names file
	#open (my $temp_names, ">", "/home/nick/Documents/fungal_hitfiles/ecc06_nrhits_taxa.txt") or die "couldn't open temp tax names file\n";

	###Will need to store the names in a hash with keys=ID numbers
	my %tax_names;
	my $linecount1 = 0;

	while (my $line = <$namesFH>){
		chomp $line;
		my @elements = split(/	\|	/, $line);
		my $number = $elements[0];
		if (exists($taxa_to_keep{$number})){
			if ($elements[3] =~ m/scientific name/){	
				print "name = $elements[1]\n";
				my $name = $elements[1];
				print "number = $number\n";
				$tax_names{$number} = $name;}
		}
		$linecount1++;
		if ($linecount1%1000 == 0) {print "Read $linecount1 lines from tax names file.\n";}
	}
 
	
	############SECTION 3: THE HARD PART################
	#This section puts everything together. 
	#Inputs: info from everything processed above
	#Outputs: A "full" taxonomy report, with a full list of species hits for "fungal" sequences ONLY

	#The original hit file must be processed into a hash with keys = sequence IDs, and values = a list of the GI numbers of the top hits. 
	#For each sequence in the original hit file, 
	#unpack the GI list into an array
	#for each value in the array: look up the taxID using the GI number
	#then use the GI number to pull the taxonomic information and the scientific name.
	#Increment a counter if fungal sequences are found
	#else it is a plant sequence
	#Print fungal sequences to output 

	#Set the output for the full report- summary of hits for every fungal sequence identified.  
	my $full_out_name = "_fungalseqs.txt";
	my $full_out_f = "$Out.$full_out_name";
	open (my $full_out, ">", "$full_out_f") or die "Could not open the outfile! Sorry!\n"; 
	
	#Counts fungal sequences 
	my $fungal_seq_counter = 0;
	my $seq_counter = 0;
	foreach my $read (keys %blast_summary){
		#Iterates through each read in the blast_summary hash
		my $hit_counter = 0;
		#Counts the number of fungal sequences
		my $fungi_counter = 0;
		#Counts basidiomycete sequences
		my $basidio_counter = 0;
		#Counts mucoromycetes
		my $muco_counter = 0;
		#Counts ascomycetes
		my $asco_counter = 0;
		#Stores info on the top aligned sequence
		my $top_hit_info;
		my $final_top_hit;
		#Split the hash value into the individual aligned sequence's taxonomic summary
		my @sequences = split('_', $blast_summary{$read});
		my @TaxIDs;
		foreach my $seq_ID (@sequences){
			#For each sequence in the array of (hit) sequences... 
			if($GI_to_Tax{$seq_ID})
			#If there is an entry in the GI_to_tax hash for the sequence ID...
			{
				#Set value from the hash containing all the GI numbers and sequence IDs
				my $taxon_ID = $GI_to_Tax{$seq_ID};
				#Push into an array with taxonomic info from all sequences
				if (exists $spp_full{$taxon_ID}){
					my $full_tax_info = $spp_full{$taxon_ID};
					my $taxon_entry = join('::', $taxon_ID, $full_tax_info);
					push (@TaxIDs, $taxon_entry);
					#Get the name from another hash 
					my $taxon_name = $tax_names{$taxon_ID};
					#If the taxon ID is found in the full list of plants and fungi... 
					#if (exists $spp_full{$taxon_ID}) {
					#Sets taxon info equal to the full taxonomic summary of the entry
					my $taxon_info = $spp_full{$taxon_ID};
					#If it is a fungal taxon...
					if ($taxon_info =~ m/_4751_/){
						$fungi_counter++;
						if ($taxon_info =~ m/_5204_/){
							$basidio_counter++;}
						if ($taxon_info =~ m/_4890_/){
							$asco_counter++;}
						if ($taxon_info =~ m/_451507_/){
							$muco_counter++;}
					}	
				
					#If this is the first (top) hit... 		
					if ($hit_counter == 0){
						#Initialize the top_hit_info variable 
						##ADDED 082216: INCLUDE FULL TAXONOMIC KEY TO ELIMINATE NON-FUNGI
						$top_hit_info = join('_', $taxon_ID, $taxon_name);
						$final_top_hit = join('::', $top_hit_info, $spp_full{$taxon_ID});}
					$hit_counter++;}
				}
			}
		#If hits have been counted...
		if ($hit_counter){
			#If at least half of the sequences are of fungal origin
			if (($fungi_counter / $hit_counter) >= 0.5){
				#Increment the fungal sequence counter
				$fungal_seq_counter++;
				#Same thing with asco, basidiomycete designations
				if (($basidio_counter / $hit_counter) >= 0.5){
					#REMOVE TOP HIT IF NOT FUNGAL
					if ($final_top_hit =~ m/_4751_/){
						print $full_out "seq:$read	basidiomycota	$top_hit_info\n";}
					else {
						my $new_top_hit = "NA";
						foreach my $lower_hit (@TaxIDs){
							if ($new_top_hit =~ /NA/){
								if ($lower_hit =~ m/_4751_/){
									$new_top_hit = $lower_hit;
									my ($nu_top_hit, $other_info) = split(/::/, $new_top_hit);
									print $full_out "seq:$read	basidiomycota	$nu_top_hit\n";}
							}
						}
					}			
					for (my $i=0; $i < 10; $i++){
						##NEED TO UPDATE EACH OF THESE LOOPS TO PROCESS ADDED TAXONOMIC INFO##
						if ($TaxIDs[$i]){
							my $full_hit = $TaxIDs[$i];
							#Split out the taxonomic code from the other stuff
							if ($full_hit =~ m/_4751_/){
								#Split out the taxonomic code from the other stuff
								my ($hit, $info) = split( /::/, $full_hit); 				
								print $full_out "$tax_names{$hit}	";}
						}
					}
				}
				print $full_out "\n";
				if (($asco_counter / $hit_counter) >= 0.5){
					if ($final_top_hit =~ m/_4751_/){
						print $full_out "seq:$read	ascomycota	$top_hit_info\n";}
					else {
						my $new_top_hit = "NA";
						foreach my $lower_hit (@TaxIDs){
							if ($new_top_hit =~ /NA/){
								if ($lower_hit =~ m/_4751_/){
									$new_top_hit = $lower_hit;
									my ($nu_top_hit, $other_info) = split(/::/, $new_top_hit);
									print $full_out "seq:$read	ascomycota	$nu_top_hit\n";}
							}
						}
					}			
					for (my $i=0; $i < 10; $i++){
						if ($TaxIDs[$i]){
							my $full_hit = $TaxIDs[$i];
							if ($full_hit =~ m/_4751_/){
								#Split out the taxonomic code from the other stuff
								my ($hit, $info) = split( /::/, $full_hit); 				
								print $full_out "$tax_names{$hit}	";}
						}	
					}
					print $full_out "\n";
				}
				if (($muco_counter / $hit_counter) >= 0.5){
					if ($final_top_hit =~ m/_4751_/){
						print $full_out "seq:$read	mucoromycota	$top_hit_info\n";}
					else {
						my $new_top_hit = "NA";
						foreach my $lower_hit (@TaxIDs){
							if ($new_top_hit =~ /NA/){
								if ($lower_hit =~ m/_4751_/){
									$new_top_hit = $lower_hit;
									my ($nu_top_hit, $other_info) = split(/::/, $new_top_hit);
									print $full_out "seq:$read	mucoromycota	$nu_top_hit\n";}
							}
						}
					}			
					for (my $i=0; $i < 10; $i++){
						if ($TaxIDs[$i]){
							my $full_hit = $TaxIDs[$i];
							if ($full_hit =~ m/_4751_/){
								#Split out the taxonomic code from the other stuff
								my ($hit, $info) = split( /::/, $full_hit); 				
								print $full_out "$tax_names{$hit}	";}
						}
					}
					print $full_out "\n";
				}	
				elsif ((($fungi_counter / $hit_counter) >= 0.5) && (($basidio_counter / $hit_counter) <= 0.5) && (($asco_counter / $hit_counter) <= 0.5) && (($muco_counter / $hit_counter) <= 0.5)){
					if ($final_top_hit =~ m/_4751_/){
						print $full_out "seq:$read	fungi	$top_hit_info\n";
					}
					else {
						my $new_top_hit = "NA";
						foreach my $lower_hit (@TaxIDs){
							if ($new_top_hit =~ /NA/){
								if ($lower_hit =~ m/_4751_/){
									$new_top_hit = $lower_hit;
									my ($nu_top_hit, $other_info) = split(/::/, $new_top_hit);
									print $full_out "seq:$read	fungi	$nu_top_hit\n";}
							}
						}
					}			
					for (my $i=0; $i < 10; $i++){
			#EXTRA CONTROL LOOP ADDED HERE
						if ($TaxIDs[$i]){
							my $full_hit = $TaxIDs[$i];
							if ($full_hit =~ m/_4751_/){
								#Split out the taxonomic code from the other stuff
								my ($hit, $info) = split( /::/, $full_hit); 				
								print $full_out "$tax_names{$hit}	";}
						}
					}
					print $full_out "\n";
				}
			}
			else {
				print "Read $read is not fungal: top hit $top_hit_info\n";}
			$seq_counter++;
		}
	}
	my $other_seqs = $seq_counter - $fungal_seq_counter;
	print "Found $fungal_seq_counter fungal reads and $other_seqs non-fungal reads.\n";
	my $r_input = "full_out_f";
	my $reportin_f = $Out.$full_out_f;	
}
