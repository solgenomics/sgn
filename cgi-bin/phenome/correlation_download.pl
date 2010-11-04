#!/usr/bin/perl -wT

=head1 DESCRIPTION
A script for downloading the correlation
coefficient and p-values for all the traits
in a population

=head1 AUTHOR(S)

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

use CXGN::DB::Connection;
use CXGN::Phenome::Population;
use CGI ();

my $cgi = CGI->new();
my %args = $cgi->Vars();
my $pop_id = $args{'population_id'} + 0;
my $corre_file = $args{'corre_file'};

my $dbh = CXGN::DB::Connection->new();
my $pop = CXGN::Phenome::Population->new( $dbh, $pop_id );
my $name = $pop->get_name();

if (-e $corre_file) {

    print $cgi->header(
        -type => 'application/x-download',
        -attachment=>"corre_data_${pop_id}.txt",
       );

   print "Pearson correlation coefficients (upper diagonal) and 
          their corresponding p-values (lower diagonal) 
          for all traits in population $name.\n\n\n";
   
    open my $f, "<$corre_file" or die "can't open file $corre_file: $!\n";

    my $cols = <$f>;
    $cols =~s/\s/\t/g;
    
    print "Traits\t" . $cols . "\n";

    while (my $row=<$f>) {
	$row =~ s/\s/\t/g;
	print $row ."\n";
    }
} else {

    print $cgi->header(
        -type   => 'text/plain',
       );
    print "No correlation analysis data file found for this population."; 

}
