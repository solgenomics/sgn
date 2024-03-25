use CatalystX::GlobalContext qw( $c );
use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People::Person;

use CXGN::Phenome::LocusgroupMember;
use CXGN::Phenome::Locus;
use CXGN::Chado::Cvterm;
use CXGN::Feed;
use CXGN::Tools::Organism;

use JSON;


my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my ($type, $locus_name, $object_id, $organism, $subject_id,  $relationship_id, $evidence_id, $reference_id, $lgm_id) = $doc->get_encoded_arguments("type", "locus_name", "object_id", "organism", "locus_id", "locus_relationship_id", "locus_evidence_code_id", "locus_reference_id", "lgm_id");



my $dbh = CXGN::DB::Connection->new();
my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
my $schema=  $c->dbic_schema('CXGN::Phenome::Schema', undef, $sp_person_id);

my ($login_person_id, $login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    if ($type eq 'browse locus') {
	if (!$organism) {  ($locus_name, $organism) = split(/,\s*/,  $locus_name); }
        $locus_name =~ /(\w+)/;
	$locus_name =$1;
	if (($locus_name) && ($organism)) {
            my $locus_query = "SELECT locus_id, locus_symbol, locus_name, common_name FROM phenome.locus 
                                   JOIN sgn.common_name USING (common_name_id) 
                                   WHERE (locus_symbol ILIKE '$locus_name%' OR locus_name ILIKE '%$locus_name%') AND (locus_id != $object_id) AND (common_name ILIKE '$organism%') AND locus.obsolete='f'"; 
            my $sth = $dbh->prepare($locus_query);
            $sth->execute();
            my ($obj_id, $symbol, $name, $obj_organism) = $sth->fetchrow_array();
	    my $available_loci;
            while($symbol) {
                $available_loci .= "$obj_id*$obj_organism -- $symbol -- $name|";
		($obj_id, $symbol, $name, $obj_organism) = $sth->fetchrow_array();
	    }
            print "$available_loci";
        }
    }

}
