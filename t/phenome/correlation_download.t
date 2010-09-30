=head1 NAME

correlation_download.t - tests for cgi-bin/phenome/correlation_download.pl


=head1 AUTHORS

Isaak Y Tecle - iyt2@cornell.edu

=cut


use strict;
use Test::More tests => 2;
use SGN::Test::WWW::Mechanize;
use lib 't/lib';
use SGN::Test;


my $base_url = $ENV{SGN_TEST_SERVER};

{
	my $mech = SGN::Test::WWW::Mechanize->new;
	$mech->get_ok("$base_url/phenome/correlation_download.pl?population_id=12&corre_file=/data/prod/tmp/r_qtl_tecle/tempfiles/corre_table_12-389UnO.txt"); 
    	$mech->content_contains('Pearson correlation coefficients');
}

