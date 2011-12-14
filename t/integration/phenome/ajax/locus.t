##tests for locus ajax functions
## Naama Medna, Feb 2011
##updated Dec. 2011

use Modern::Perl;

use lib 't/lib';
use Test::More;

use SGN::Test::Data qw/create_test/;
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $mech = SGN::Test::WWW::Mechanize->new();

my $dbh = $mech->context->dbc->dbh;
my $schema = $mech->context->dbic_schema('CXGN::Phenome::Schema');

my ($a_locus_id, $homolog_id) ; # need this for later when deleting the test data
# instantiate an new locus object and save to database
my $locus = $schema->resultset('Locus')->find_or_create(
    {
        locus_name => 'testing_locus_111222',
        locus_symbol => 'testing_111222',
        common_name_id=>1,
    });
# now we need a temp allele for this locus
my $allele = $locus->create_related('alleles' , {allele_symbol => 'test_allele111222' } );

my $locus_id = $locus->locus_id();
diag("created temporaty test locus  $locus_id");
my $term = 'testing';
$mech->get_ok("/ajax/locus/autocomplete?term=$term");


$mech->content_contains($term);
$mech->content_contains($locus->locus_name);
$mech->content_contains($locus->locus_symbol);
####
####
$mech->while_logged_in( { user_type=>'submitter' }, sub {
#ontology, locus network,

##need to add all these as cvterms ..
#solanaceae_phenotype--SP:000001--fruit size
##my $ontology_input = $c->req->param('term_name');
    ##   my $relationship   = $c->req->param('relationship'); # a cvterm_id
    ## my ($relationship_id) = $cvterm_rs->find( { cvterm_id => $relationship } )->dbxref_id;
    ## my $evidence_code  = $c->req->param('evidence_code'); # a cvterm_id
#$mech->post("/ajax/locus/associate_ontology?object_id=$locus_id&term_name=$onto_term&relationship=$rel_id&evidence_code=$ev_code_id");

##$mech->content_like(qr//);

##then check if the page displays the ontology term
#$mech->get_ok("/locus/$locus_id/ontologies");

    # add publciation then test if it prints on the page
    $mech->get_ok("/locus/$locus_id/references");

    ##associate new locus

    #new locus for associating witht the test locus
    my $a_locus = $schema->resultset('Locus')->find_or_create(
        {
            locus_name => 'testing_locus_111223',
            locus_symbol => 'testing_111223',
            common_name_id=>1,
        });
    $a_locus_id = $a_locus->locus_id;

    #create cvterm for the relationship
    my $homolog_cvterm     = create_test('Cv::Cvterm', { name  => 'homolog' });
    $homolog_id = $homolog_cvterm->cvterm_id;
    $mech->post("/ajax/locus/associate_locus" , { locus_id=>$locus_id , object_id=>$a_locus_id, locus_relationship_id=>$homolog_id } );
    #my %params = map { $_ => $c->request->body_parameters->{$_} } qw/
    #       locus_reference_id locus_evidence_code_id
    #       object_id locus_relationship_id locus_id

    $mech->content_like(qr/success/);

    #locus network
    $mech->get_ok("/locus/$locus_id/network");

    #obsolete the locus group memner
    #"/ajax/locus/obsolete_locus_group_member"

    #now test the printed page
    $mech->get_ok("/locus/$locus_id/network");

    #add new unigene
    #post request
    #/locus/$locus_id/associate_unigene"

    #test display
    $mech->get_ok("/locus/$locus_id/unigenes");

    #obsolete the unigene
##"/ajax/locus/obsolete_locus_unigene"

#test the display
                        });
##


# delete test locus and allele objects we created
END {
    if( $mech && $locus_id  ) {
        my $write_dbh = $mech->context->dbc('sgn_test')->dbh;
        $write_dbh->do( "DELETE FROM phenome.$_ WHERE locus_id = ?", undef, $locus_id )
            for "allele", "locus";
        if ($a_locus_id) {
            $write_dbh->do( "DELETE FROM phenome.$_ WHERE locus_id = ?", undef, $a_locus_id )
                for "allele", "locus";
            $write_dbh->do( "DELETE FROM phenome.locusgroup WHERE relationship_id = ?", undef, $homolog_id );
        }
    }
}

done_testing();

