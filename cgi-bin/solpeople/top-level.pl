#DEPRECATED
#####################
#This page now points to the url /solpeople/profile/<sp_person_id> in the controller SGN::Controller::People
#####################

use strict;
use SGN::I18N ();


use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::Login;
use CXGN::People;
use CXGN::People::Person;
use CXGN::BlastWatch;
use CXGN::Phenome::Locus;
use CXGN::Cview::MapFactory;
use CXGN::Page::FormattingHelpers qw/info_section_html page_title_html
  info_table_html simple_selectbox_html
  html_optional_show columnar_table_html/;

our $c;
use CatalystX::GlobalContext qw($c);


    my SGN::I18N $ui_people_i18n = SGN::I18N::translate($c);
    my %ui_people_text = (
        welcome => SGN::I18N::translate($ui_people_i18n, 'community.people.welcome', 'Welcome ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        log_out => SGN::I18N::translate($ui_people_i18n, 'community.people.log_out', '[log out]', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        view_or_update_personal_contact_and_research_information => SGN::I18N::translate($ui_people_i18n, 'community.people.view_or_update_personal_contact_and_research_information', 'View or update personal (contact and research) information', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        update_account_information => SGN::I18N::translate($ui_people_i18n, 'community.people.update_account_information', 'Update account information', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        post_to_sgn_forum => SGN::I18N::translate($ui_people_i18n, 'community.people.post_to_sgn_forum', 'Post to SGN forum', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        test_website_error_handling => SGN::I18N::translate($ui_people_i18n, 'community.people.test_website_error_handling', 'Test website error handling', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        view_user_stats => SGN::I18N::translate($ui_people_i18n, 'community.people.view_user_stats', 'View user stats', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        create_new_user_account => SGN::I18N::translate($ui_people_i18n, 'community.people.create_new_user_account', 'Create new user account', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        create_new_organization => SGN::I18N::translate($ui_people_i18n, 'community.people.create_new_organization', 'Create new organization', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        your_current_user_status_is => SGN::I18N::translate($ui_people_i18n, 'community.people.your_current_user_status_is', 'Your current user status is ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        you_have_the_maximum_user_privileges_on_sgn => SGN::I18N::translate($ui_people_i18n, 'community.people.you_have_the_maximum_user_privileges_on_sgn', 'You have the maximum user privileges on SGN.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        you_have_maximum_user_privileges_on_sgn => SGN::I18N::translate($ui_people_i18n, 'community.people.you_have_maximum_user_privileges_on_sgn', 'You have maximum user privileges on SGN.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        please_contact => SGN::I18N::translate($ui_people_i18n, 'community.people.please_contact', 'Please contact ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        to_upgrade_to_a => SGN::I18N::translate($ui_people_i18n, 'community.people.to_upgrade_to_a', ' to upgrade to a ', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        account_with_more_privileges_submitters_can_upload_user_maps_est_data_and_become_locus_editors => SGN::I18N::translate($ui_people_i18n, 'community.people.account_with_more_privileges_submitters_can_upload_user_maps_est_data_and_become_locus_editors', ' account with more privileges. Submitters can upload user maps, EST data, and become locus editors.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        if_you_would_like_to_change_your_user_status => SGN::I18N::translate($ui_people_i18n, 'community.people.if_you_would_like_to_change_your_user_status', ' if you would like to change your user status.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
    );

my $page = CXGN::Page->new( "solpeople main menu", "john" );
my $dbh = CXGN::DB::Connection->new();
my $site_name = $c->config->{project_name};

my $sp_person_id = CXGN::Login->new($dbh)->verify_session();

my $sp = CXGN::People::Person->new( $dbh, $sp_person_id );
unless ($sp_person_id) {
    $page->error_page( SGN::I18N::translate($ui_people_i18n, 'community.people.login_id_not_found', 'Login ID not found.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        "", "", "Login ID not found: $sp_person_id" );
}
unless ( $sp->get_username() ) {
    $page->error_page( SGN::I18N::translate($ui_people_i18n, 'community.people.username_not_found', 'Username not found.', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
        "", "", "Username not found for sp_person_id '$sp_person_id'" );
}
my $username = $sp->get_first_name() . " " . $sp->get_last_name();

#my $research_update=$sp->get_research_update();
#my $contact_update=$sp->get_contact_update();

$page->add_style( text => <<EOS);
div#queryTable
{
margin: 0px 0px 0px 0px;
display: none;
}
EOS
$page->header();

print <<END_HTML;

<script type = "text/javascript">
<!--
    function toggleLayer(whichLayer) {
	if (document.getElementById) {
	    var style2 = document.getElementById(whichLayer).style; 
	    style2.display = style2.display? "":"block";
	}
	else if (document.all) {
	    var style2 = document.all[whichLayer].style;
	    style2.display = style2.display? "":"block";
	}
	else if (document.layers) {
	    var style2 = document.layers[whichLayer].style;
	    style2.display = style2.display? "":"block";
	}
    }
    function showSequence(sequence) {
	document.getElementById("Heading").innerHTML="<strong>Full sequence: </strong>";
	document.getElementById("fullSequence").innerHTML=sequence;
    }
    function hideSequence() {
	document.getElementById("Heading").innerHTML="";
	document.getElementById("fullSequence").innerHTML="";
    }
//-->
</script>
END_HTML

print page_title_html("My $site_name");
print qq|<div align="center">$ui_people_text{welcome}<b>$username</b></div>\n|;
print
qq|<div align="right" style="margin-bottom: 0.5em">Not $username? <a href="login.pl?logout=yes">$ui_people_text{log_out}</a></div>\n|;
print info_section_html( title => SGN::I18N::translate($ui_people_i18n, 'community.people.general_tools', 'General Tools', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }), contents => <<EOHTML);
    <a href="personal-info.pl?action=edit&sp_person_id=$sp_person_id">$ui_people_text{view_or_update_personal_contact_and_research_information}</a><br />
    <a href="change-account.pl?action=edit&sp_person_id=$sp_person_id">$ui_people_text{update_account_information}</a><br />
    <a href="/forum/topics.pl">$ui_people_text{post_to_sgn_forum}</a><br />
EOHTML

# my $queries =
#     qq|<div id="queryTable">|
#   . CXGN::BlastWatch::get_queries( $dbh, $sp_person_id )
#   . '</div>';
# print info_section_html( title => 'BLAST Watch', contents => <<EOHTML);
#     <div style="margin-bottom: 1em">BLAST Watch is an SGN service that lets users submit recurring BLAST queries to SGN.  Our software repeats your BLAST search every week and notifies you by email if the BLAST results change.</div>
#     <a href="/tools/blast/watch/index.pl">Submit a query to SGN BLAST Watch</a><br />
#     <a href="javascript:toggleLayer('queryTable');" title="View your BLAST Watch queries">View your BLAST Watch queries</a>
#     $queries
# EOHTML

#return 1 if the first term is eq to one of the other terms given
sub in(@) { ## no critic (Subroutines::ProhibitSubroutinePrototypes) # Existing callers rely on prototype parsing for this CGI helper.
    my $t = shift;
    ( grep { $t eq $_ } @_ ) ? 1 : 0;
}

#now assemble the sequencing tools stuff
if ( in( $sp->get_user_type, qw/curator sequencer/ ) ) {

    #make a form for uploading TPF and AGP files
    my $tpf_agp_upload = do {
        if ( $sp->get_user_type eq 'curator' ) {
            tpf_agp_upload_forms(<<EOHTML);
      <!-- the string 'TYPE' will be replaced in each instance by tpf_agp_upload_forms() -->
<label for="chrnuminputTYPE">For Chromosome #: </label><input id="chrnuminputTYPE" name="chr" type="text" size="2" maxlength="2" />
EOHTML
        }
        elsif ( $sp->get_user_type eq 'sequencer'
            and my @projects =
            grep { $_ >= 1 && $_ <= 12 }
            $sp->get_projects_associated_with_person )
        {
            my $chrinput =
              @projects > 1
              ? simple_selectbox_html(
                name    => 'chr',
                choices => \@projects,
                label   => 'For Chromosome #:',
              )
              : qq|For Chromosome #: <b>$projects[0]</b> <input type="hidden" value="$projects[0]" name="chr" />|;
            tpf_agp_upload_forms($chrinput);
        }
    };

    print info_section_html( title => 'Sequencer Tools', contents => <<EOHTML);
<a href="attribute_bacs.pl">Attribute a BAC to your chromosome sequencing project</a><br />
<a href="/maps/physical/clone_il_view.pl">View/update BAC IL mapping information (list view)</a><br />
<div style="vertical-align: middle; font-weight: bold"><a href="/maps/physical/clone_reg.pl">View/update all BAC registry info (list view) <img style="border: none" src="/documents/img/new.gif" /></a></div>
<a href="/sequencing/tpf.pl">View TPF Files</a><br />
<a href="/sequencing/agp.pl">View AGP Files</a><br />
$tpf_agp_upload
EOHTML
}

# if( in( $sp->get_user_type(), qw/submitter curator/ ) )
# {
#   print info_section_html(title => 'EST Submission Pages', contents => <<EOHTML);
# <a href="/data-submit/top-level.pl">Data submission start page</a>
# EOHTML
# }

if ( in( $sp->get_user_type(), qw/submitter curator/ ) ) {
    print info_section_html( title => 'QTL data submission',
        contents => <<EOHTML);
<a href="/phenome/qtl_form.pl">Upload and analyse your QTL data</a>
EOHTML
}

my @pops = CXGN::Phenome::Population->my_populations($sp_person_id);

if (@pops) {
    my $pop_list = my_populations(@pops);
    print info_section_html( title => 'Populations', contents => $pop_list );
}

#### solGS submitted jobs list ##########
my $solgs_jobs = SGN::Controller::solGS::AnalysisQueue->solgs_analysis_status_log($c);

my $solgs_jobs_table;

if(@$solgs_jobs) {
    $solgs_jobs_table =  columnar_table_html(
	headings   => [ 'Analysis name', 'Submitted on', 'Status', 'Result page'],
	data       => $solgs_jobs,
	__alt_freq => 2,
	__align    => 'llll',
	);
} else {
    $solgs_jobs_table = 'You have no submitted jobs.'
}

print info_section_html( 
    title    => 'solGS submitted analysis jobs', 
    contents => $solgs_jobs_table 
    );

#######


if ( $sp->get_user_type() eq 'curator' ) {
    print info_section_html( title => SGN::I18N::translate($ui_people_i18n, 'community.people.curator_tools', 'Curator Tools', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }), contents => <<EOHTML);
<a href="/solpeople/admin/crash_test.pl">$ui_people_text{test_website_error_handling}</a><br />
<a href="/solpeople/admin/stats.pl">$ui_people_text{view_user_stats}</a><br />
<a href="/solpeople/admin/quick_create_account.pl">$ui_people_text{create_new_user_account}</a><br />
<a href="/solpeople/admin/create_organization.pl">$ui_people_text{create_new_organization}</a>
EOHTML
}

if ( $sp->get_user_type() =~ /curator/i ) {
    my $publications =
qq| <a href= "/search/pub_search.pl">Search the SGN publication database </a><br />|;
    $publications .=
qq| <a href= "/search/pub_search.pl?w9b3_assigned_to=$sp_person_id">See your assigned publications</a><br />|;
    $publications .=
qq| <a href= "/search/pub_search.pl?w9b3_status=pending">See publications pending curation</a><br />|;
    $publications .=
qq| <a href= "/chado/fetch_pubmed.pl">Load new publications from PubMed</a><br />|;

    print info_section_html(
        title    => 'Literature mining',
        contents => $publications
    );
}

if ( $sp->get_user_type() =~ /submitter|curator|sequencer/i ) {

    my @loci =
      CXGN::Phenome::Locus::get_locus_ids_by_editor( $dbh, $sp_person_id );
    my $top  = 50;
    my $more = 0;
    my $max  = @loci;
    if ( @loci > 24 ) {
        $more = @loci - 24;
        $max  = 24;
    }

    my $locus_editor_info = qq { None.<br /> };
    if ( @loci > 0 ) {
        $locus_editor_info = "";
    }

    for ( my $i = 0 ; $i < ($max) ; $i++ ) {
        my $locus    = CXGN::Phenome::Locus->new( $dbh, $loci[$i] );
        my $symbol   = $locus->get_locus_symbol();
        my $locus_id = $locus->get_locus_id();

        $locus_editor_info .=
qq { <a href="/phenome/locus_display.pl?locus_id=$locus_id&amp;action=view">$symbol</a> };
    }
    if ($more) {
        $locus_editor_info .=
qq|<br><b>and <a href="/search/locus/>$more more</a></b><br />|;
    }

    print info_section_html(
        title    => 'Loci with Editor Privileges',
        contents => $locus_editor_info
    );

    my @annotated_loci =
      CXGN::Phenome::Locus::get_locus_ids_by_annotator( $dbh, $sp_person_id );

    my $more = 0;
    my $max  = @annotated_loci;
    if ( @annotated_loci > 24 ) {
        $more = @annotated_loci - 24;
        $max  = 24;
    }

    my ( $locus_annotations, $more_annotations );

    for ( my $i = 0 ; $i < $top ; $i++ ) {
        my $locus    = CXGN::Phenome::Locus->new( $dbh, $annotated_loci[$i] );
        my $symbol   = $locus->get_locus_symbol();
        my $locus_id = $locus->get_locus_id();

        if ( $i < $max ) {
            $locus_annotations .=
qq | <a href="/locus/$locus_id/view">$symbol</a> |;
        }
        else {
            $more_annotations .=
qq { <a href="/locus/$locus_id/view">$symbol</a> };
        }
    }

    if ($more) {
        $locus_annotations .= " and $more more, not shown.<br />";

        $locus_annotations .=
          html_optional_show( 'locus_annotations', 'Show more',
            qq|<div class="minorbox">$more_annotations</div> |,
          );
    }

    $locus_annotations .=
qq| <a href="../phenome/recent_annotated_loci.pl">[View annotated loci by date]</a> |;
    print info_section_html(
        title    => 'Annotated Loci',
        contents => $locus_annotations
    );

    my $map_factory = CXGN::Cview::MapFactory->new($dbh);
    my @user_maps   = $map_factory->get_user_maps();
    my $html        = "";

    if ( @user_maps > 0 ) {
        $html .=
"<table alt=\"\" ><tr><td><i>Name</i></td><td></td><td></td><td><i>status</i></td></tr>";
        foreach my $um (@user_maps) {
            my $public = " (not public) ";
            if ( $um->get_map()->get_is_public() ) { $public = "(public)"; }
            $html .=
                "<tr><td><b>"
              . $um->get_short_name()
              . "</b></td><td> <a href=\"/cview/umap.pl?action=view&amp;user_map_id="
              . $um->get_id()
              . "\" >[view]</a></td><td><a href=\"/cview/umap.pl?action=edit&amp;user_map_id="
              . $um->get_id()
              . "\">[configure]</a></td><td>$public</td></tr>";

        }
        $html .= "</table>";
    }

    # BROKEN!
    #    print info_section_html(title => 'User Maps', contents=> <<EOHTML);
    #    <a href="/cview/upload_usermap.pl">Upload new user map</a><br />
    #	<br />
    #	$html
    #EOHTML

}

my $user_type = $sp->get_user_type();
my $user_info = {
    user => qq{ $ui_people_text{your_current_user_status_is}<b>$user_type</b>. $ui_people_text{please_contact}<a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a>$ui_people_text{to_upgrade_to_a}<b>submitter</b>$ui_people_text{account_with_more_privileges_submitters_can_upload_user_maps_est_data_and_become_locus_editors} },

    submitter => qq{ $ui_people_text{your_current_user_status_is}<b>$user_type</b>. $ui_people_text{you_have_the_maximum_user_privileges_on_sgn} $ui_people_text{please_contact}<a href="mailto:sgn-feedback\@sgn.cornell.edu">SGN</a>$ui_people_text{if_you_would_like_to_change_your_user_status}},

    curator => qq{ $ui_people_text{your_current_user_status_is}<b>$user_type</b>. },

    sequencer => qq{ $ui_people_text{your_current_user_status_is}<b>$user_type</b>. $ui_people_text{you_have_maximum_user_privileges_on_sgn} },

    genefamily_editor => qq{ $ui_people_text{your_current_user_status_is}<b>$user_type</b>. },
};

print info_section_html( title => SGN::I18N::translate($ui_people_i18n, 'community.people.user_status', 'User Status', undef, { entities => '\x{0080}-\x{10FFFF}', decode => 0 }),
    contents => $user_info->{$user_type} );

$page->footer();

#returns a string containing a TPF and an AGP upload form,
#with the single argument interpolated in
sub tpf_agp_upload_forms {
    my $chrinput = shift;
    my ( $chrinput_agp, $chrinput_tpf ) = ( $chrinput, $chrinput );
    $chrinput_agp =~ s/TYPE/_agp/g;
    $chrinput_tpf =~ s/TYPE/_tpf/g;
    return <<EOHTML;
<div style="margin-top: 1em">
  <b>Upload Accessioned Golden Path (AGP) File</b><br />
  <form action="/sequencing/agp.pl" method="post" enctype="multipart/form-data">
    $chrinput_agp
    <input type="hidden" name="filetype" value="agp" />
    <label for="agpinput">File: </label>
    <input id="agpinput" type="file" name="agp_file" value="Upload AGP file" /><input type="submit" value="Submit" />
  </form>
</div>
<div style="margin-top: 1em">
  <b>Upload Tiling Path Format (TPF) File</b><br />
  <form action="/sequencing/tpf.pl" method="post" enctype="multipart/form-data">
    $chrinput_tpf
    <input type="hidden" name="filetype" value="tpf" />
    <label for="tpfinput">File: </label>
    <input id="tpfinput" type="file" name="tpf_file" value="Upload TPF file" /><input type="submit" value="Submit" />
  </form>
</div>
EOHTML
}

sub my_populations {
    my @pops = @_;
    my $pops_list;

    foreach my $pop (@pops) {
        my $pop_name  = $pop->get_name();
        my $pop_id    = $pop->get_population_id();
        my $is_public = $pop->get_privacy_status();
        if ($is_public)    { $is_public = 'is publicly available'; }
        if ( !$is_public ) { $is_public = 'is not publicly available yet'; }
        $pops_list .=
qq |<a href="/qtl/population/$pop_id">$pop_name</a> <i>($is_public)</i><br/>|;
    }

    return $pops_list;
}
