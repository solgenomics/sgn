
=head1 DESCRIPTION
A script for downloading population 
phenotype raw data in a tab delimited format.

=head1 AUTHOR(S)

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

use CXGN::Phenome::Population;
use CGI;

use CatalystX::GlobalContext qw( $c );


my $cgi           = CGI->new();
my $population_id = $cgi->param('population_id'); 
my $dbh           = $c->dbc->dbh;
my $pop           = CXGN::Phenome::Population->new( $dbh, $population_id );
my $name          = $pop->get_name();
my $p_file        = $pop->phenotype_file($c);



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

