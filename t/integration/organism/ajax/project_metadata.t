
## a simple test for the organism ajax functions 
## Lukas Mueller, Jan 2011

use Modern::Perl;

use lib 't/lib';
use Test::More tests=>17;
use SGN::Test::WWW::Mechanize;

use CXGN::Chado::Organism;

my $mech = SGN::Test::WWW::Mechanize->new();

my $schema = $mech->context->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

# instantiate an organism object and save to database
#
my $o = CXGN::Chado::Organism->new($schema);
$o->set_genus('test');
$o->set_species('test');

$o->store();
my $o_id = $o->get_organism_id();
diag("created temp organism $o_id");
$mech->get_ok("/organism/$o_id/metadata/?action=view");
#print $mech->content();
$mech->content_contains('html');

$mech->while_logged_in( { user_type=>'submitter' }, sub { 
    $mech->get_ok("/organism/$o_id/metadata/?action=store&genome_project_funding_agencies=NSF");
#    print $mech->content();
    $mech->content_contains('success');
    $mech->get_ok("/organism/$o_id/metadata/?action=view");
    $mech->content_contains('NSF');
    $mech->get_ok("/organism/$o_id/metadata/?action=store&genome_project_funding_agencies=USDA");
    $mech->content_contains('success');
    $mech->get_ok("/organism/$o_id/metadata/?action=view");
    $mech->content_contains('USDA');
});

# hard delete the temp organism object
#
my $sth = $schema->storage->dbh->prepare("DELETE FROM organism WHERE organism_id=?");
my $success = $sth->execute($o_id);
ok($success, "Hard delete of temp organism $o_id test object");



