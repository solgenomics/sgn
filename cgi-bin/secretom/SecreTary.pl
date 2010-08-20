#!/usr/bin/perl -w
use strict;

#use lib '/data/local/cxgn/core/sgn-tools/secretom';
#use lib '/home/tomfy/Desktop/secretom_290710';
use SecreTarySelect;
use SecreTaryAnalyse;

my @STAarray = ();
while(<>){
	if(/^>(\S+)/){
		my $id = $1;
		my $sequence = <>;
		chomp $sequence;
  
		my $trunc_length = 100;

       #	my $limits = [$min_score, $min_tmh_length, $max_tmh_length, $min_beg, $max_beg];
		my $STAobj = SecreTaryAnalyse->new($id, substr($sequence,0,$trunc_length)); # , $limits);
		push @STAarray, $STAobj;	
	}
}



my $min_tmpred_score1 = 1500;
my $min_tmh_length1 = 17;
my $max_tmh_length1 = 33;
my $max_tmh_beg1 = 30;

my $min_tmpred_score2 = 900;
my $min_tmh_length2 = 17;
my $max_tmh_length2 = 33;
my $max_tmh_beg2 = 17;

my $min_AI22 = 71.304;
my $min_Gravy22 = 0.2636;
my $max_nDRQPEN22 = 8;
my $max_nNitrogen22 = 34;
my $max_nOxygen22 = 32;
my @STSparams = ($min_tmpred_score1, $min_tmh_length1, $max_tmh_length1, $max_tmh_beg1,
		$min_tmpred_score2, $min_tmh_length2, $max_tmh_length2, $max_tmh_beg2,
		$min_AI22, $min_Gravy22, $max_nDRQPEN22, $max_nNitrogen22, $max_nOxygen22);
for (my $i=0; $i<1; $i++){
  #  $STSparams[11] = $i + 26;
    for (my $j=0; $j<1; $j++){
#	$STSparams[12] = $j + 26;
my $STSobj = SecreTarySelect->new(@STSparams);	

my ($count_g1, $count_g2, $count_fail)= $STSobj->Categorize(\@STAarray);
print "counts: $count_g1, $count_g2, $count_fail \n";
    }
}
