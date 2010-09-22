use strict;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::DB::Connection;
use CXGN::Phenome::LocusDbxref;
use CXGN::Login;
use CXGN::Contact;
use CXGN::People::Person;
use CXGN::Feed;

my $dbh = CXGN::DB::Connection->new();
my ( $login_person_id, $login_user_type ) =
  CXGN::Login->new($dbh)->verify_session();

if (   $login_user_type eq 'curator'
    || $login_user_type eq 'submitter'
    || $login_user_type eq 'sequencer' )
{

    my $doc = CXGN::Scrap::AjaxPage->new();
    my ( $object_dbxref_id, $type, $action ) =
      $doc->get_encoded_arguments( "object_dbxref_id", "type", "action" );
    my $link;

    eval {
        if ( $type eq 'locus' )
        {
            my $locus_dbxref =
              CXGN::Phenome::LocusDbxref->new( $dbh, $object_dbxref_id );
            if ( $action eq 'unobsolete' ) {
                $locus_dbxref->unobsolete();
            }
            else { $locus_dbxref->obsolete(); }
            my $locus_id = $locus_dbxref->get_locus_id();
            $link = "http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id";
        }
        elsif ( $type eq 'individual' ) {
            my $individual_dbxref =
              CXGN::Phenome::Individual::IndividualDbxref->new( $dbh,
                $object_dbxref_id );
            if ( $action eq 'unobsolete' ) { $individual_dbxref->unobsolete(); }
            else                           { $individual_dbxref->obsolete(); }

            my $individual_id = $individual_dbxref->get_individual_id();
            $link = "http://www.sgn.cornell.edu/phenome/individual.pl?individual_id=$individual_id";
        }
    };
    if ($@) { warn "Obsoleting ontology term association failed!  $@"; }
    else {

        my $subject = "[Ontology-$type association $action] ";
        my $person = CXGN::People::Person->new( $dbh, $login_person_id );
        my $user = $person->get_first_name() . " " . $person->get_last_name();
        my $user_link = qq|http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$login_person_id|;

        my $fdbk_body = "$user ($user_link) just $action ontology-$type association from phenome. $type - dbxref\n
         id=$object_dbxref_id  \n $link";
        CXGN::Contact::send_email( $subject, $fdbk_body,
            'sgn-db-curation@sgn.cornell.edu' );
        CXGN::Feed::update_feed( $subject, $fdbk_body );
    }

}

