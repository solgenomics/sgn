
package SGN::Controller::People;

use Moose;

use URI::FromHash 'uri';
use CXGN::Login;
use CXGN::People::Person;
use Data::Dumper;
use CXGN::Phenome::Population;
use SGN::Controller::solGS::AnalysisQueue;
use CXGN::Page::FormattingHelpers qw/info_section_html page_title_html info_table_html simple_selectbox_html html_optional_show columnar_table_html/;
use CXGN::Phenome::Locus;

BEGIN { extends 'Catalyst::Controller' };

sub people_search : Path('/search/people') Args(0) {
    my $self = shift;
    my $c = shift;
    $c->stash->{template} = '/search/people.mas';


}

#Code migrated from /cgi-bin/solpeople/top-level.pl
sub people_top_level : Path('/solpeople/profile') Args(1) {
    my $self = shift;
    my $c = shift;
    my $person_id = shift;
    my $dbh = $c->dbc->dbh;

    #will redirect user to login page if they are not logged in.
    my $user_id=CXGN::Login->new($dbh)->verify_session();
    if (!$user_id) {

        $c->res->redirect(uri( path => '/user/login', query => { goto_url => $c->req->uri->path_query } ) );
        $c->detach();
    }
    my $users_profile;
    if ($person_id == $user_id) {
        $users_profile = 1;
    }
    my @roles = $c->user->get_roles;
    my %roles_hash;
    foreach (@roles) {
        $roles_hash{$_} = 1;
    }

    my $p = CXGN::People::Person->new($dbh, $person_id);
    my $user_type = $p->get_user_type;

    if ($users_profile) {

        # User's populations sections
        my @pops = CXGN::Phenome::Population->my_populations($person_id);
        my $pops_list;
        foreach my $pop (@pops) {
            my $pop_name  = $pop->get_name();
            my $pop_id    = $pop->get_population_id();
            my $is_public = $pop->get_privacy_status();
            if ($is_public)    { $is_public = 'is publicly available'; }
            if ( !$is_public ) { $is_public = 'is not publicly available yet'; }
            $pops_list .= qq |<a href="/qtl/population/$pop_id">$pop_name</a> <i>($is_public)</i><br/>|;
        }
        if (!$pops_list) {
            $pops_list = '<h4>You have no populations.</h4>';
        }
        $c->stash->{populations_list} = $pops_list;

        #User Loci section
        my @loci = CXGN::Phenome::Locus::get_locus_ids_by_editor( $dbh, $person_id );
        my $top  = 50;
        my $more = 0;
        my $max  = @loci;
        if ( @loci > 24 ) {
            $more = @loci - 24;
            $max  = 24;
        }
        my $locus_editor_info = "<h4>You have no loci to edit.</h4>";
        if ( @loci > 0 ) {
            $locus_editor_info = "";
        }
        for ( my $i = 0 ; $i < ($max) ; $i++ ) {
            my $locus    = CXGN::Phenome::Locus->new( $dbh, $loci[$i] );
            my $symbol   = $locus->get_locus_symbol();
            my $locus_id = $locus->get_locus_id();
            $locus_editor_info .= qq { <a href="/phenome/locus_display.pl?locus_id=$locus_id&amp;action=view">$symbol</a> };
        }
        if ($more) {
            $locus_editor_info .= qq|<br><b>and <a href="/search/locus/>$more more</a></b><br />|;
        }
        $c->stash->{loci_editor_privileges} = $locus_editor_info;

        my @annotated_loci = CXGN::Phenome::Locus::get_locus_ids_by_annotator( $dbh, $person_id );
        $more = 0;
        $max  = @annotated_loci;
        if ( @annotated_loci > 24 ) {
            $more = @annotated_loci - 24;
            $max  = 24;
        }
        my ( $locus_annotations, $more_annotations );
        for ( my $i = 0 ; $i < $top ; $i++ ) {
            my $locus    = CXGN::Phenome::Locus->new( $dbh, $annotated_loci[$i] );
            my $symbol   = $locus->get_locus_symbol() ? $locus->get_locus_symbol() : '';
            my $locus_id = $locus->get_locus_id() ? $locus->get_locus_id() : '';

            if ( $i < $max ) {
                $locus_annotations .= qq | <a href="/locus/$locus_id/view">$symbol</a> |;
            } else {
                $more_annotations .= qq { <a href="/locus/$locus_id/view">$symbol</a> };
            }
        }
        if ($more) {
            $locus_annotations .= " and $more more, not shown.<br />";

            $locus_annotations .= html_optional_show( 'locus_annotations', 'Show more', qq|<div class="minorbox">$more_annotations</div> | );
        }
        $locus_annotations .= qq| <a href="../phenome/recent_annotated_loci.pl">[View annotated loci by date]</a> |;
        $c->stash->{loci_annotations} = $locus_annotations;

        #User status section
        my $user_info = {
            user => qq{ Your current user status is <b>$user_type</b>. Please contact <a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a> to upgrade to a <b>submitter</b> account with more privileges. Submitters can upload user maps, EST data, and become locus editors. },
            submitter => qq{ Your current user status is <b>$user_type</b>. You have the maximum user privileges on SGN. Please contact <a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a> if you would like to change your user status.},
            curator => qq{ Your current user status is <b>$user_type</b>. },
            sequencer => qq{ Your current user status is <b>$user_type</b>. You have maximum user privileges on SGN. },
            genefamily_editor => qq{ Your current user status is <b>$user_type</b>. },
        };
        $c->stash->{user_status} = $user_info->{$user_type};
    }

    my $allow_cvterm_edits = 0;
    if ($c->config->{allow_cvterm_edits}) {
        $allow_cvterm_edits = 1;
    }

    $c->stash->{site_name} = $c->config->{project_name};
    $c->stash->{allow_cvterm_edits} = $allow_cvterm_edits;
    $c->stash->{user_roles} = \%roles_hash;
    $c->stash->{sp_person_id} = $p->get_sp_person_id;
    $c->stash->{username} = $c->user->get_object->get_username;
    $c->stash->{first_name} = $p->get_first_name;
    $c->stash->{last_name} = $p->get_last_name;
    $c->stash->{is_users_profile} = $users_profile;
    $c->stash->{template} = '/people/profile.mas';


}

1;
