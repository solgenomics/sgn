use strict;
use warnings;
use CGI qw /param/;
use CXGN::Chado::Cvterm;

#  Displays a static cvterm detail page.

use CatalystX::GlobalContext qw( $c );


my $q   = CGI->new();
my $dbh = CXGN::DB::Connection->new();

my $cvterm_id = $q->param("cvterm_id") + 0;
my $cvterm_accession = $q->param("cvterm_name");
my $cvterm;

if ( $cvterm_accession  ) {
    $cvterm = CXGN::Chado::Cvterm->new_with_accession( $dbh, $cvterm_accession);
    $cvterm_id = $cvterm->get_cvterm_id();
} elsif ( $cvterm_id  ) {
    $cvterm = CXGN::Chado::Cvterm->new( $dbh, $cvterm_id );
}

unless ( $cvterm_id && $cvterm_id =~ m /^\d+$/ ) {
    $c->throw( is_client_error => 1, public_message => 'Invalid arguments' );
}



$c->forward_to_mason_view(
    '/chado/cvterm.mas',
    cvterm    => $cvterm,
    );


