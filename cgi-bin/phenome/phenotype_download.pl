use CatalystX::GlobalContext qw( $c );
#!/usr/bin/perl -wT

=head1 DESCRIPTION
A script for downloading population 
phenotype raw data in tab delimited format.

=head1 AUTHOR(S)

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

use CXGN::DB::Connection;
use CXGN::Phenome::Population;
use CXGN::Scrap;
use Cache::File;
use CGI ();
use CatalystX::GlobalContext qw( $c );

my $scrap = CXGN::Scrap->new();
my $dbh   = CXGN::DB::Connection->new();

my %args = $scrap->get_all_encoded_arguments();
my $population_id = $args{population_id};

my $pop = CXGN::Phenome::Population->new( $dbh, $population_id );
my $name = $pop->get_name();


my $p_file = $pop->phenotype_file($c);

my $cgi = CGI->new();

if (-e $p_file) {   
   
    print $cgi->header(
	-type => 'application/x-download',
	-attachment => "phenotype_data_${population_id}.txt",
	);

    print "phenotype data for $name\n\n\n";
 
    open my $f, "<$p_file" or die "can't open file $p_file: $!\n";
  
    while (my $row=<$f>) {
	$row =~ s/,/\t/g;
	print "$row";
    }

}
else {
    print $cgi->header ('text/plain');   
    print "No Phenotype data file found for this population";
}

