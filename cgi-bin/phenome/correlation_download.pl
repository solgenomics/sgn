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
use CGI qw /:cgi-lib/ ;
use Tk;
use Tk::DialogBox;
use Tk::MsgBox;

my $cgi = CGI->new();
my %args = $cgi->Vars();
my $pop_id = $args{'population_id'};
my $corre_file = $args{'corre_file'};

my $dbh = CXGN::DB::Connection->new();
my $pop = CXGN::Phenome::Population->new( $dbh, $pop_id );
my $name = $pop->get_name();


print
"Pragma: \"no-cache\"\nContent-Disposition:filename=corre_data_${pop_id}.txt\nContent-type:application/data\n\n";


if (-e $corre_file) {
    
    print 'Pearson correlation coefficients and their 
           corresponding p-values for all traits in 
           population'	.  $name . "\n\n\n";
 

    open my $f, "<$corre_file" or die "can't open file $corre_file: $!\n";
    
    my $cols = <$f>;
    print "Traits\t" . $cols;
    
    while (my $row=<$f>) {
	print $row;
    }
}
