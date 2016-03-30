use warnings;
use strict;
use Getopt::Long;

####################################################################################################
# This program produces lists of orthogroups
# Needs:
# Req: Numerical list of desired genomes to explore in order to look for orthogroups
# input: An input file with an all vs all blast that includes at least the numbers in Req
# Optional:
# verbose mode 
# Output file name of the outputfile
#
## Example (Find the core of the genomes 1,2,3)
# $perl allvsall.pl -R 1,2,3 -v 0 -i file.blast
# Where file.blast is the blast of allvsall genomes (obtained with the script 1_Makeblast.pl 
#
#
# 
# Nelly Selem Lab Evolution of Metabolic Diversity
# nselem84@gmail.com
##################################################################################################################

#############################################
## Subs
sub Options;
sub bestHit(); #Lines on a file, Arguments hash of hashes reference
sub ListBidirectionalBestHits; #Hash of hashes reference (empty), Hash of hashes full with best hits
sub IsEverybody();
sub SelecGroup(); 

############################################
#Variables
my $verbose;
my $inputblast;
my $output;
 
my %BH = (); #Hash de hashes
my %BiBestHits;
my @Required=Options(\$verbose,\$inputblast,\$output);
#################################################################################################
########################################################
## Main
## 1 Find Best Hits
print "\nFinding Hits for each gene, takes some minutes, be patient!\n"; 
&bestHit(\%BH,$inputblast);

## 2 Find Bidirectional Best Hits
#print "##\n BREAK 1\n #####";
print "Now finding Best Bidirectional Hits List\n";
&ListBidirectionalBestHits(\%BiBestHits,\%BH);

## 3 Find ortho groups of selected Genomes
print ("Selecting List that contains orthologs from all desired genomes\n");
&SelecGroup(\%BiBestHits,@Required);

##############################################################################
##################### Subs implementation

sub Options{ 
	my $Req; ## Genoms list to look for otrho groups

	GetOptions ("In=s" => \$inputblast,"Out=s" => \$output,"Req=s" => \$Req,"verbose" => \$verbose) or die("Error in command line arguments\n");
	if(!$inputblast) {
		die("Please provide an all vs all blast file");
		} 
	if (!$output){
		$output="Out.Ortho";
		}
	if(!$Req){
		die ("You must specify from which organisms you desire an ortho-group");
		}	
	else{
		my @Required=split(",",$Req);
		if ($verbose){
			print("You want ortho groups of the following genomes\n");
			for my $req(@Required){
				print "$req \t";
				}
				print("\n");
			}
		return @Required;
		}
	}

#__________________________________________________________________________________________________
sub bestHit(){
	my $BH=shift;
	my $input=shift;
	open(FILE, $input);

	foreach my $line(<FILE>) {
		my @sp = split(/\t/, $line);
		#print $sp[0] . "\t" . $sp[1] . "\t\t" . $sp[2] . "\n";
		my $queryL=$sp[0];
		my $hitL=$sp[1];
		my $identityL=$sp[2];
		my $evalueL=$sp[10];

		my $o1 = ''; ## Get organism from column A (The query)
		if($queryL=~ m/\|(\d+)$/) { $o1 = $1; }

		my $o2 = '';
		if($hitL =~ m/\|(\d+)$/) {  
			$o2 = $1; ## Get Organism from Column B (The hit)
			#if($o1 eq $o2) { next; }#We dont want the same organism
		} 

	##sp[0] query gen from column A
	#If there are not previous hits for the query
		if(!exists $BH->{$queryL}) { $BH->{$queryL} = (); }## Then I start a list
		if(!exists $BH->{$queryL}{$o2}) { $BH->{$queryL}{$o2} = [0]; } ## If it does not exist a hit for genColumnA and orgColumnB 
									     ## Start in 0.

		if($evalueL > $BH->{$queryL}{$o2}[0]) { ## If for the organism the new line has a better match
			$BH->{$queryL}{$o2} = [$evalueL, $hitL]; ## I change it ## If the score is the same
							       ## I will lost paralogs (same score and choose arbitrary one)
							       ## It would be a good idea to improve this part
		} elsif($evalueL > $BH->{$queryL}{$o2}[0]) {
			push(@{$BH->{$queryL}{$o2}}, $hitL);
		}
		
	}
	close(FILE);
	} #### Data Structure BEst Hit (BH) has been fullfilled with the best hit of each gene

#__________________________________________________________________________________________________

sub ListBidirectionalBestHits(){
## Arguments HAsh Best Hits
## Return a hash of hashes with bidirectional best hits for each gen
	my $RefBiBestHits=shift;
	my $RefBH=shift;
	my $count=0;
	for my $gen (keys %$RefBH) {
		for my $org (keys %{$RefBH->{$gen}}) {#Organismos kk
			
			my $hit=$RefBH->{$gen}{$org}[1];
			if($hit and( exists $RefBH->{$hit})) {
				my $oo1 = '';
				if($gen =~ m/\|(\d+)$/) { 
					$oo1 = $1; 
					}
				if(exists $RefBH->{$hit}{$oo1}[1] and $gen eq $RefBH->{$hit}{$oo1}[1]) {
					$RefBiBestHits->{$gen}{$org}=$hit;
					$count++;
					}
				}
			}
		}
	}
#__________________________________________________________________________________________________

sub SelecGroup(){
	my $refBBH=shift;
	open (OUT,">./OUTSTAR/$output");
	#my $refRequired=shift;
	for my $gen (keys %$refBBH){
		my $oo1 = '';
		if($gen =~ m/\|(\d+)$/) { $oo1 = $1; }
		#print "$oo1\t";
		#print " $gen: @ORGS \n"; ## Uncomment to see organism where query has Best Bidirectional Hit

		my @ORGS=sort (keys %{$refBBH->{$gen}});
		#print " $gen: @ORGS \n"; ## Uncomment to see organism where query has Best Bidirectional Hit

		if ($oo1~~@Required){	
			#print "$oo1: @Required\t";	
			if(&IsEverybody(\@Required,\@ORGS) ){
				############### Print ortologous list of the subgroup ######################
 				print OUT "$oo1\t";
				for(my $i=0;$i<scalar  @ORGS;$i++){			
					my $ortoi;
					if ($ORGS[$i]==$oo1){
						$ortoi=$gen; ## If it does not has ortologous then it is itself
						}
					else{   if($ORGS[$i]~~@Required){
							 $ortoi=$refBBH->{$gen}{$ORGS[$i]};
							}
						}
					if($ortoi){
						print OUT "$ortoi\t";
						}
					}		
				print OUT "\n";
				}
			}
		}
	close OUT;
	}

#_________________________________________________________________________________
sub IsEverybody(){
	#print "Checking Intersection";
	my ($Required,$query)=@_;
	my $flag=1;
	for my $element(@$Required){
		#print("elemento $element\n");
		if($element~~@$query){
		$flag=$flag*1;	
		#print("Its in query \n")
			}
		else{
		      #print("Its not in query \n");
		      return 0;
			}
		}
	return $flag;
}

