#!/usr/bin/perl -w
use strict;
use SecreTarySelect;
use SecreTaryAnalyse;

my @STAarray = ();
while(<>){
	if(/^>(\S+)/){
		my $id = $1;
		my $sequence = <>;
		chomp $sequence;
  
		my $trunc_length = 100;
		my $STAobj = SecreTaryAnalyse->new($id, substr($sequence,0,$trunc_length)); 
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

my $STSobj = SecreTarySelect->new(@STSparams);	

my $STApreds = $STSobj->Categorize(\@STAarray);

my $result_string   = "";
my $count_pass      = 0;
my $show_max_length = 62;
foreach (@$STApreds) {
    my $STA = $_->[0];
    my $out = $_->[1];
    $out =~ /\((.*)\)\((.*)\)/;
    my ($soln1, $soln2) = ($1, $2);
    my $prediction = substr($out, 0, 3 );
    $count_pass++ if ( $prediction eq "YES" );
    my $id = substr( $STA->get_sequence_id() . "                    ", 0, 15 );
    my $sequence = $STA->get_sequence();
    print "$id  $prediction  $soln1 $soln2 ", substr($sequence, 0, 50), "\n";
}
print "$count_pass predicted signal peptides out of ", scalar @$STApreds, "\n";
