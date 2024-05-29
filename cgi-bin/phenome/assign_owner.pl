use Modern::Perl;
use warnings;

use CXGN::Scrap::AjaxPage;
use CXGN::Login;
use CXGN::People::Person;
use CXGN::Feed;
use CatalystX::GlobalContext '$c';

my $dbh = $c->dbc->dbh;

my ( $login_person_id, $login_user_type ) =
  CXGN::Login->new($dbh)->verify_session();

if ( $login_user_type eq 'curator' ) {
    my $doc = CXGN::Scrap::AjaxPage->new();
    $doc->send_http_header();
    my ( $user_info, $object_type, $object_id, $sp_person_id ) =
      $doc->get_encoded_arguments( "user_info", "object_type", "object_id",
        "sp_person_id" );

    #query for retreiving user information
    if ($user_info) {
        my $user_query = $dbh->prepare(
"SELECT sp_person_id, first_name, last_name, user_type FROM sgn_people.sp_person 
                                     WHERE (first_name ilike '%$user_info%' OR last_name ilike '%$user_info%')
                                     ORDER BY last_name
                                    "
        );
        $user_query->execute();
        my ( $sp_person_id, $first_name, $last_name, $user_type ) =
          $user_query->fetchrow_array();
        my $users;
        my @roles = ();
        while ($first_name) {
            my $person = CXGN::People::Person->new( $dbh, $sp_person_id );
            @roles = $person->get_roles;
            my $role_string = join ',', @roles;
            $users .= "$sp_person_id*$last_name, $first_name [$role_string]|";
            ( $sp_person_id, $first_name, $last_name, $user_type ) =
              $user_query->fetchrow_array();
        }
        print "$users";
    }

#setting the new object owner. Only curators can do this.
#if the user has a 'user' account it will be updated to a 'submitter' first
#executed when javascript sends object_type and object_id , and sp_person_id args
    if ( $object_type && $object_id ) {
        my $new_owner = CXGN::People::Person->new( $dbh, $sp_person_id );

        eval {

            #if the new owner is not a submitter, assign that role
            if ( !$new_owner->has_role('submitter') ) {
                $new_owner->add_role('submitter');
            }
            my $query;
            if ( $object_type eq 'locus' ) {
                $query = $dbh->prepare(
"INSERT INTO phenome.locus_owner (sp_person_id, locus_id, granted_by)
                                        VALUES (?,?,?)"
                );
                $query->execute( $sp_person_id, $object_id, $login_person_id );

 #if the current owner of the locus is a logged-in SGN curator, do an obsolete..
                if ( $login_user_type eq 'curator' ) {
                    my $remove_curator_query =
"UPDATE phenome.locus_owner SET obsolete='t', modified_date= now()
                                          WHERE locus_id=? AND sp_person_id IN (SELECT sp_person_id FROM sgn_people.sp_person_roles WHERE sp_role_id  = (SELECT sp_role_id FROM sgn_people.sp_roles WHERE name = 'curator') )";
                    my $remove_curator_sth =
                      $dbh->prepare($remove_curator_query);
                    $remove_curator_sth->execute($object_id);
                }

            }
            elsif ( $object_type eq 'individual' ) {
                $query = $dbh->prepare(
                    "UPDATE phenome.individual SET sp_person_id= ?
                                         WHERE indvidual_id= ?"
                );
                $query->execute( $sp_person_id, $object_id );

            }
            elsif ( $object_type eq 'stock' ) {
                my $stock =
                  $c->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado', $sp_person_id )
                  ->resultset("Stock::Stock")
                  ->find( { stock_id => $object_id } );
                $stock->create_stockprops(
                    { 'sp_person_id' => $sp_person_id },
                    {
                        'cv_name'                => 'local',
                        autocreate               => 1,
                        'allow_duplicate_values' => 1
                    }
                );

            }
            else { exit(); }
        };

        if ($@) {
            my $message = "assigning $object_type owner failed! $@";
            warn $message;
            return $message;
        }
        else {
            my $subject =
              "[New $object_type owner assigned] $object_type $object_id";
            my $person = CXGN::People::Person->new( $dbh, $login_person_id );
            my $user =
              $person->get_first_name() . " " . $person->get_last_name();
            my $user_link =
              qq |solgenomics.net/solpeople/personal-info.pl?sp_person_id=$login_person_id|;

            my %links = (
                'locus' => qq |solgenomics.net/locus/$object_id/view/|,
                'stock' => qq |solgenomics.net/stock/$object_id/view/|,
            );
            my $object_link = $links{$object_type};
            my $owner = CXGN::People::Person->new( $dbh, $sp_person_id );
            my $owner_name =
              $owner->get_first_name() . " " . $owner->get_last_name();
            my $owner_link =
              qq |solgenomics.net/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
            my $fdbk_body =
"curator $user ($user_link) has assigned a new owner ($owner_name, $owner_link) for $object_type $object_link \n ";
            CXGN::Contact::send_email( $subject, $fdbk_body,
                'sgn-db-curation@sgn.cornell.edu' );
            CXGN::Feed::update_feed( $subject, $fdbk_body );
        }
    }
}
