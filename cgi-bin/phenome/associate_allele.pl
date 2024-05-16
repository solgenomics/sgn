use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Login;
use CXGN::Chado::Stock;
use CXGN::People::Person;
use CXGN::Feed;
use JSON;
use CatalystX::GlobalContext '$c';

my $doc = CXGN::Scrap::AjaxPage->new();
$doc->send_http_header();

my $dbh = $c->dbc->dbh;
my $sp_person_id = $c->user() ? $c->user->get_object()->get_sp_person_id() : undef;
my $schema = $c->dbic_schema('Bio::Chado::Schema' , 'sgn_chado', $sp_person_id);
my($login_person_id,$login_user_type)=CXGN::Login->new($dbh)->verify_session();

if ($login_user_type eq 'curator' || $login_user_type eq 'submitter' || $login_user_type eq 'sequencer') {

    my $doc = CXGN::Scrap::AjaxPage->new();
    my ($stock_id, $allele_id, $sp_person_id) = $doc->get_encoded_arguments("stock_id", "allele_id", "sp_person_id");

    my %error = ();
    my $json = JSON->new();

    eval {
        my $stock = CXGN::Chado::Stock->new($schema, $stock_id);
        $stock->associate_allele($allele_id, $sp_person_id);
        $error{"response"} = "Associated allele $allele_id with stock $stock_id!";
    };
    if ($@) {
	$error{"error"} = "Associate allele failed! " . $@;
	CXGN::Contact::send_email('associate_allele.pl died',$error{"error"}, 'sgn-bugs@sgn.cornell.edu');
    } else  {
	my $subject="[New stock associated] allele $allele_id";
	my $person= CXGN::People::Person->new($dbh, $login_person_id);
	my $user=$person->get_first_name()." ".$person->get_last_name();
	my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;

   	my $fdbk_body="$user ($user_link has associated stock $stock_id with allele $allele_id  \n
         http://www.sgn.cornell.edu/stock/$stock_id/view";
        CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
	CXGN::Feed::update_feed($subject,$fdbk_body);
    }
    my $jobj = $json->objToJson(\%error);
    print  $jobj;

}
