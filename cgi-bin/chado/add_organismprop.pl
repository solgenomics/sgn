use Bio::Chado::Schema;
use strict;
use warnings;
use JSON;
use CXGN::Scrap::AjaxPage;
use Try::Tiny;
use CXGN::Login;

my $dbh = $c->dbc->dbh;

my %status;
my $json = JSON->new();
my $doc  = CXGN::Scrap::AjaxPage->new();

$doc->send_http_header();

my ( $person_id, $user_type ) = CXGN::Login->new($dbh)->has_session();

my ( $species, $prop_name, $prop_value ) =
  $doc->get_encoded_arguments( "species", "prop_name", "prop_value" );

#if (!$prop_name || !$prop_value) { die "Must pass prop_name and prop_value! \n"; }

if ( $user_type &&  grep { $_ eq $user_type } qw( curator  submitter sequencer ) ) {

    my $schema = $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' );

    try {
        my $org = $schema->resultset('Organism::Organism')
                         ->find( { species => $species } )
                         ->create_organismprops(
                             { $prop_name => $prop_value },
                             { autocreate => 1 },
                            );
        $status{"pass"} = "Success, the object was added to the table.";
    }
    catch {
        warn "error adding organismprop:\n$_";
        $status{"fail"} = <<'';
Error: Failed to mark the organism as SOL100.  Please select an organism from the suggestion list.  If this error persists, please contact sgn-feedback@solgenomics.net

    };
}
else {
    $status{"fail"} =
'You don\'t have the right privileges for adding a new organism to the sol100 project. Please contact sgn-feedback@solgenomics.net for more info.';
}
my $jobj = $json->encode( \%status );
print "$jobj";
