use strict;
use warnings;

use POSIX;
use List::Util qw/sum/;

use Carp;

use Bio::Range;
use Bio::Graphics::Gel;

use CXGN::Apache::Error;

use CXGN::TomatoGenome::BACSubmission;
use CXGN::DB::Connection;
use CXGN::DB::Physical;
use CXGN::DB::DBICFactory;

use CXGN::Fish;    # helper routines for FISH data.

use CXGN::Genomic::Search::Clone;
use CXGN::Login;
use CXGN::Map;
use CXGN::Marker;
use CXGN::Page;

use CXGN::Page::FormattingHelpers qw/ page_title_html
  info_section_html
  info_table_html
  columnar_table_html
  commify_number
  simple_selectbox_html
  truncate_string
  tooltipped_text
  /;
use CXGN::People;
use CXGN::People::BACStatusLog;
use CXGN::People::PageComment;
use CXGN::People::Person;
use CXGN::Search::CannedForms;
use CXGN::TomatoGenome::BACPublish;
use CXGN::Tools::Identifiers qw/link_identifier/;
use CXGN::Tools::List qw/all distinct any min max str_in/;
use CXGN::Tools::Text;

use CatalystX::GlobalContext '$c';

# some of the newer parts of the page are in a controller object
my $self = $c->controller('Clone::Genomic');

our %link_pages = (
    marker_page        => '/search/markers/markerinfo.pl?marker_id=',
    map_page           => '/cview/map.pl?map_id=',
    overgo_report_page => '/maps/physical/overgo_stats.pl',
    agi_page           => 'http://www.genome.arizona.edu/fpc/tomato/',
    bac_page           => '/maps/physical/clone_info.pl?id=',
    sgn_search_page    => '/search/direct_search.pl',
    plate_design_page => '/maps/physical/list_overgo_plate_probes.pl?plate_no=',
    list_bacs_by_plate => '/maps/physical/list_bacs_by_plate.pl?by_plate=',
    mapviewer          => '/cview/view_chromosome.pl?show_physical=1&map_id=',
    overgo_explanation => '/maps/physical/overgo_process_explained.pl',
    read_info_page     => '/maps/physical/clone_read_info.pl'
);
$link_pages{physical_map_page} = $link_pages{'map_page'} . '1&physical=1';
$link_pages{contig_page}       = $link_pages{'agi_page'};

# Start a new SGN page.
my $page  = CXGN::Page->new( 'BAC Data', 'Rob Buels' );
my $dbh   = CXGN::DB::Connection->new();
my $chado = CXGN::DB::DBICFactory->open_schema('Bio::Chado::Schema');

$page->jsan_use(qw/ MochiKit.Base MochiKit.Async /);

# Get arguments from Apache.
my %params = $page->get_all_encoded_arguments;

#### bac status stuff ####
#if someone is logged in, get their information so they can have the option of updating the status of this bac
our ( $person, $person_id, $fname, $lname, $username, $user_type ) =
  ( '', '', '', '', '', '' );
my @person_projects;
$person_id = CXGN::Login->new($dbh)->has_session();
if ($person_id) {
    $person = CXGN::People::Person->new( $dbh, $person_id );
    if ($person) {
        $person_id       = $person->get_sp_person_id();
        $fname           = $person->get_first_name() || '';
        $lname           = $person->get_last_name() || '';
        $username        = "$fname $lname";
        $user_type       = $person->get_user_type();
        @person_projects = $person->get_projects_associated_with_person;
    }
}

## get the clone in question ###
#support legacy identifiers, but complain
my $clone;
my $clonequery = CXGN::Genomic::Search::Clone->new->new_query;
$clonequery->from_request( \%params );

#is a random clone wanted?
if ( $params{random} and $params{random} eq 'yes' ) {
    ( $params{id} ) = $dbh->selectrow_array(<<EOSQL);
select clone_id from genomic.clone
where bad_clone is null or bad_clone='0'
order by random()
limit 1
EOSQL
}

if ( $params{id} ) {
    $clone = CXGN::Genomic::Clone->retrieve(
        $params{id} + 0 )    #the +0 makes sure it's numeric
      or clone_not_found_page( $page,
        "No clone with id $params{id} could be found.", $clonequery );

}
elsif ( $params{bac_id} ) {

    $clone = CXGN::Genomic::Clone->retrieve( $params{bac_id} + 0 )
      or clone_not_found_page( $page,
        "No clone with id $params{bac_id} could be found.", $clonequery );

}
elsif ( $params{cu_name} || $params{az_name} ) {
    my $search         = CXGN::Genomic::Search::Clone->new;
    my $query          = $search->new_query;
    my $clonename      = $params{cu_name} || $params{az_name};
    my $orig_clonename = $clonename;
    $clonename =~ s/^P(\d{3})(\D{1})(\d{2})/LE_HBa0$1$2$3/;
    $query->clone_name("='$clonename'");
    my $result = $search->do_search($query);
    $result->total_results > 1
      and $page->error_page(
        "SGN bug: multiple clones with clone name $orig_clonename were found.");

#clone_not_found_page($page, "Multiple clones with clone name $orig_clonename (a.k.a. $clonename) were found.  That's an internal bug.", $link_pages, \%params,$clonequery);
    $result->total_results < 1
      and clone_not_found_page( $page,
        "No clones with clone name $orig_clonename were found.", $clonequery );

    $clone = $result->next_result;
}

# make sure we have a clone at this point
unless ( $clone && $clone->clone_id ) {
    clone_not_found_page( $page,
        "No clones found matching the search criteria.", $clonequery );
}

my $clone_id = $clone->clone_id;

####################################
# OUTPUT THE PAGE
####################################

my $head_extra = <<EOEXTRA;
<style type="text/css">
<!--
FORM.changebutton {
   display: inline;
}

/*FORM.changebutton BUTTON[type="submit"] {
  padding-left: 2px;
  padding-right: 2px;
  line-height: 1.3;
  background-color: #fff;
  color: #009;
  border: none;
  margin: none;
}*/

FORM.changebutton BUTTON {
  margin: 0;
  padding: 0;
  background-color: #fff;
  color: #009;
  border: 1px solid #fff;
  font-size: 10px;
}

FORM.changebutton BUTTON:hover {
  border: 1px solid #444;
}


SPAN.bgcolorstatus1 FORM.changebutton BUTTON,
SPAN.bgcolorstatus1 SPAN.colorme {
   background-color: #ddd;
   color: #000;
   border: 1px solid #444;
}

SPAN.bgcolorstatus2 FORM.changebutton BUTTON,
SPAN.bgcolorstatus2 SPAN.colorme {
   background-color: #ffff66;
   color: #000;
   border: 1px solid #444;
}
SPAN.bgcolorstatus3 FORM.changebutton BUTTON, 
SPAN.bgcolorstatus3 SPAN.colorme {
	background-color: #66ff66;
   color: #000;
   border: 1px solid #444;
}
SPAN.bgcolorstatus4 FORM.changebutton BUTTON,
SPAN.bgcolorstatus4 SPAN.colorme {
	background-color: #9999ff;
   color: #000;
   border: 1px solid #444;
}
SPAN.colorme {
   white-space: nowrap;
}
-->
</style>
EOEXTRA

my $az_name = $clone->clone_name;
$page->header( "Clone $az_name", undef, $head_extra );
print page_title_html("Clone $az_name");

print info_section_html(
    title       => 'Clone &amp; library',
    collapsible => 1,
    contents    => '<table style="margin: 0 auto"><tr><td>'
      . $c->render_mason( '/genomic/clone/clone_summary.mas', clone => $clone )
      . '</td><td>'
      . $c->render_mason(
        '/genomic/library/library_summary.mas',
        library => $clone->library_object
      )
      . info_table_html(
        __title => 'Ordering Information',
        'BAC Clones' =>
'BAC clones can be ordered from the <a href="http://ted.bti.cornell.edu/cgi-bin/TFGD/order/order.cgi?item=clone">clone ordering page at TFGD</a>',
        __tableattrs => 'width="100%" height="100%"',
      )
      . '</td></tr></table>'
);

my $overgo_html = render_overgo( $clone, $dbh );

#get data on our computational associations with markers
my $computational_associations_html =
  render_computational_associations( $clone, $dbh );

#get data on manual associations
my $manual_associations_html = do {
    my $mas = $dbh->selectall_arrayref( <<EOSQL, undef, $clone->clone_id );
select marker_id,pubmed_id,sp_person_id,comment, first_name, last_name, organization
from physical.manual_associations
join sgn_people.sp_person using(sp_person_id)
where clone_id = ?
EOSQL

    if ( $mas and @$mas ) {
        join '', map "$_\n", map {
            my ( $marker_id, $pubmed_id, $sp_person_id, $comment_text, $fname,
                $lname, $org )
              = @$_;
            my $marker = CXGN::Marker->new( $dbh, $marker_id );
            '<div style="border: 1px solid #bbb">' . info_table_html(
                Marker => qq|<a href="$link_pages{marker_page}$marker_id">|
                  . $marker->name_that_marker . '</a>',
                Publication => (
                    $pubmed_id
                    ? qq|<a href="http://www.ncbi.nlm.nih.gov/pubmed/$pubmed_id">PubMed $pubmed_id</a>|
                    : '<span class="ghosted">unpublished</span>'
                ),

                'Submitted by' => "$fname $lname " . ( $org ? "($org)" : '' ),
                __multicol     => 3,
                __border       => 0,
              )
              . info_table_html(
                Comment => $comment_text || '<span class="ghosted">none</span>',
                __border => 0,
              )
              . '</div>'
        } @$mas;
    }
    else {
        '';
    }
};

my $physical_map_link = do {
    if (   $overgo_html
        || $computational_associations_html
        || $manual_associations_html )
    {
        my $chr = $clone->chromosome_num;
        my $url =
            "/cview/view_chromosome.pl?map_id=p9&hilite="
          . $clone->clone_name
          . "&chr_nr=$chr";
        qq|<a href="$url">View on physical map chromosome $chr</a>|;
    }
    else {
        '';
    }
};

my $fish_link = do {
    my $on_fish_map =
      $dbh->selectall_arrayref( <<EOQ, undef, $clone->clone_id );
select map_id, chromo_num
from sgn.fish_result
where clone_id = ?
EOQ
    if ( $on_fish_map && @$on_fish_map ) {
        my $url =
            "/cview/view_chromosome.pl?map_id=$on_fish_map->[0][0]&hilite="
          . $clone->clone_name
          . "&chr_nr=$on_fish_map->[0][1]";
        qq|<a href="$url">View on FISH map chromosome $on_fish_map->[0][1]</a>|;
    }
};

my $reg_info = $clone->reg_info_hashref;

#output physical mapping stuff
if ( $self->_is_tomato($clone) ) {
    print info_section_html(
        title       => 'Physical mapping',
        collapsible => 1,
        contents    => info_section_html(
            title         => 'Fingerprint Contig Builds (FPC)',
            is_subsection => 1,
            contents      => join "\n",
            '<dl class="fpc_results">',
            (
                sort {
                    my ( $ad, $bd ) = map m|(20\d\d).+</dt>|, $a, $b;
                    $bd <=> $ad
                  }    #< sort by date in the FPC desc
                  (
                    map
                    { #< do a search and render links for each gbrowse FPC data source
                        my $ds = $_;
                        my @x  = $ds->xrefs(
                            { -attributes => { Name => $clone->clone_name } } );
                        my $ext_desc = ( $ds->extended_description
                              || 'no extended description' );

                        if (@x) {
                            map {
                                join '',
                                  (
                                    '<dt><a href="', $_->url,
                                    '">',            $ds->description,
                                    '</a></dt> ',    '<dd>',
                                    $ext_desc,       '</dd>',
                                  )
                            } @x;
                        }
                        else {
                            '<dt class="ghosted">not present in '
                              . $ds->description
                              . '</dt><dd class="ghosted">'
                              . $ext_desc . '</dd>';
                        }
                      }
                      grep $_->description =~
                      /FPC/i,    #< select list of GBrowse FPC data sources
                    map $_->data_sources,
                    $c->enabled_feature('gbrowse2')
                  ),
                render_old_arizona_fpc( $dbh, $clone ),
            ),
            '</dl>',
          )
          . info_section_html(
            title =>
qq|Marker matches - overgo <a class="context_help" href="/maps/physical/overgo_process_explained.pl">what's this?</a>|,
            contents      => $overgo_html,
            is_subsection => 1,
          )
          . info_section_html(
            title         => qq|Marker matches - BLAST|,
            contents      => $computational_associations_html,
            is_subsection => 1,
          )
          . info_section_html(
            title         => qq|Marker matches - manual|,
            contents      => $manual_associations_html,
            is_subsection => 1,
          )
          . info_section_html(
            title         => qq|Physical map (from marker matches)|,
            contents      => $physical_map_link,
            empty_message => 'Not on Physical Map',
            is_subsection => 1,
          )
          . info_section_html(
            title         => "FISH map",
            contents      => $fish_link,
            is_subsection => 1,
            empty_message => 'Not on FISH map',
          )
          . info_section_html(
            title    => "FISH images",
            contents => CXGN::Fish::fish_image_html_table(
                CXGN::DB::Connection->new,
                $clone->clone_id
            ),
            is_subsection => 1,
          )
          . info_section_html(
            title    => "IL Mapping",
            subtitle => do {
                if ( str_in( $user_type, qw/sequencer curator/ ) ) {
                    my $qstr = do {
                        my $q = CXGN::Genomic::Search::Clone->new->new_query;
                        $q->clone_id( '=?', $clone_id );
                        $q->to_query_string;
                    };
qq|<a style="font-weight: bold" href="clone_reg.pl?$qstr">Edit IL mapping info</a>|;
                }
                else {
                    undef;
                }
            },
            is_empty =>
              !any( map $_->{val}, @{$reg_info}{qw/il_proj il_chr il_bin/} ),
            contents => info_table_html(
                __multicol => 3,
                __border   => 0,
                'Assigned to project' =>
qq|<span id="clone_il_mapping_project">$reg_info->{il_proj}{disp}</span>|,
                'IL-mapped to chromosome' =>
qq|<span id="clone_il_mapping_chr">$reg_info->{il_chr}{disp}</span>|,
                'IL-mapped to IL segment' =>
qq|<span id="clone_il_mapping_line">$reg_info->{il_bin}{disp}</span>|,
              )
              . info_table_html(
                __border => 0,
                'IL mapping notes' =>
qq|<span id="clone_il_mapping_notes">$reg_info->{il_notes}{disp}</span>|,
              ),
            is_subsection => 1,
          )

    );
}
else {
    print info_section_html(
        title         => 'Physical mapping',
        collapsible   => 1,
        contents      => '',
        empty_message => 'not available',
    );
}

#output sequencing status
print info_section_html(
    title       => 'Sequencing',
    collapsible => 1,
    contents => sequencing_content( $self, $c, $clone, $person, $dbh, $chado ),
);

# compute content for prelim. annot section
my $latest_seq = $clone->latest_sequence_name;

print info_section_html(
    title       => 'Sequence Annotations',
    collapsible => 1,
    contents    => info_table_html(
        __border => 0,
        Browse   => join(
            "<br />\n",
            map '<a href="' . $_->url . '">' . $_->text . '</a>',
            map {
                my $gb = $_;
                $gb->xrefs($latest_seq), $gb->xrefs( $clone->clone_name )
              } $c->enabled_feature('gbrowse2')
          )
          || '<span class="ghosted">'
          . $clone->clone_name
          . ' has no browsable sequence annotations</span>',
        Download => (
            $self->_is_tomato($clone)
            ? render_tomato_bac_annot_download( $c, $clone )
            : '<span class="ghosted">not available</span>'
        ),
    ),
);

#print field for page comments
print CXGN::People::PageComment->new( $dbh, "BAC", $clone->clone_id )
  ->get_html();

# Search again.
print info_section_html(
    title       => 'Search again',
    collapsible => 1,
    contents =>
      CXGN::Search::CannedForms::clone_search_form( $page, $clonequery ),
);

$page->footer;

######################################################################
#
#  Subroutines
#
######################################################################

#compare an in-vitro and in-silico restriction fragment set
#against eachother, rate how well they match up on a scale of 0 to 1
sub frag_match_score {
    my @a = @{ shift() };
    my @b = @{ shift() };

    my @max_hs = map {
        my $b = $_ || 1;
        max map {
            my $a = $_ || 1;
            min( $a / $b, $b / $a );
        } @a;
    } @b;

    #print join(',',@max_hs),"\n";
    return sum(@max_hs) / max( scalar(@a), scalar(@b) );
}

sub clone_not_found_page {

    my ( $page, $message, $query ) = @_;
    $page->header('Clone not found.');

    # No BAC found.
    print page_title_html('CLONE NOT FOUND');

    print qq|<h2>$message</h2>\n|;

    print info_section_html(
        title => 'Search again',
        contents =>
          CXGN::Search::CannedForms::clone_search_form( $page, $query ),
    );

    # Finish.
    $page->footer;
    exit;
}

sub sequencing_content {
    my ( $self, $c, $clone, $person, $dbh, $chado ) = @_;
    my $clone_id = $clone->clone_id;

    my $bac_status_log = CXGN::People::BACStatusLog->new($dbh);

    #get bac status
    my $sequencing_content = '';

    #print STDERR "user type '$user_type'\n";
    my $welcome_message_html = do {
        if ( $person
            && str_in( $person->get_user_type, qw/sequencer curator/ ) )
        {
            "Welcome, <b>"
              . $person->get_first_name . ' '
              . $person->get_last_name
              . "</b>. You are logged in as a $user_type.\n";
        }
      }
      || '';

    my $sequencing_status_html = do {
        my ( $status, ) = $bac_status_log->get_status( $clone->clone_id );
        $status;
    };

    my $chr = $clone->chromosome_num;

    my $sequencing_project_html =
      sequencing_project_html( $user_type, $chr, $clone );

    my $latest_seq = $clone->latest_sequence_name;
    my $seqlen     = $clone->seqlen;
    my $is_finished =
      $latest_seq && !( $latest_seq =~ /-\d+$/ ) && $clone->seq !~ /N/;
    my %sequencing_files =
      $self->_is_tomato($clone)
      ? CXGN::TomatoGenome::BACPublish::sequencing_files( $clone,
        $c->config->{'ftpsite_root'} )
      : $self->_potato_seq_files( $c, $clone );

    #make info on the full sequence of this clone
    my $sequence_info = do {
        if ($latest_seq) {
            my $tot_len  = commify_number($seqlen);
            my $dl_links = '';

            if ( $sequencing_files{seq} ) {
                $dl_links .= <<EOHTML
    <a href="/genomic/clone/$clone_id/annotation/download?set=all;format=seq">[Download fasta]</a><br />
EOHTML

            }
            if ( $sequencing_files{tar} ) {
                my $tarsize =
                  sprintf( "%0.2f", ( -s $sequencing_files{tar} ) / 1_000_000 );
                $dl_links .= <<EOHTML
    <a href="/genomic/clone/$clone_id/annotation/download?set=all;format=tar">[Download full submission]</a> ($tarsize MB)
EOHTML

            }

            my $gb = $clone->genbank_accession($chado);
            $gb =
              $gb
              ? ( link_identifier( $gb, 'genbank_accession' ) || $gb )
              . ' (GenBank)'
              : '';
            <<EOHTML
<table width="100%"><tr>
<td>
  $tot_len bp <br />
  $latest_seq <br/>
  $gb
</td>
<td><a href="/maps/physical/clone_sequence.pl?clone_id=$clone_id">[View]</a><br />
$dl_links
</td>
</tr></table>
EOHTML
        }
        else {
            qq|<span class="ghosted">Sequence not available.</span>|;
        }
    };

    #make an ftp site link
    my $ftp_link = $self->_ftp_seq_repos_link( $c, $clone );

    #make displays of the in-vitro restriction fragments we have in our
    #records, versus the predicted in-silico fragments.  also, set a flag
    #if any of them have low match scores
    my $low_restriction_match_score = 0;      #< flag
    my $restriction_match_threshold = 0.70;
    my $restriction_frags_html      = do {
        my @iv_frags = $clone->in_vitro_restriction_fragment_sizes();

        join '', map {
            my $fingerprint_id = shift @$_;
            my $enzyme         = shift @$_;
            my $iv_frags       = $_;
            my $gel_img =
qq|<img border="1" style="margin-right: 1em" src="clone_restriction_gel_image.pl?id=$clone_id&amp;enzyme=$enzyme&amp;fp_id=$fingerprint_id" />|;
            if ( my $is_frags =
                $clone->in_silico_restriction_fragment_sizes($enzyme) )
            {
                $is_frags = [ grep { $_ > 1000 } @$is_frags ];
                my $match_score =
                  ( frag_match_score( $is_frags, $iv_frags ) +
                      frag_match_score( $iv_frags, $is_frags ) ) / 2;
                $low_restriction_match_score = 1
                  if $match_score < $restriction_match_threshold;
                my $frag_listing = info_table_html(
                    __sub    => 1,
                    __border => 0,
                    "$enzyme <i>in vitro</i> ("
                      . scalar(@$iv_frags)
                      . ')' => join( ', ', @$iv_frags ),
                    "$enzyme <i>in silico</i> ("
                      . scalar(@$is_frags)
                      . ')' => join( ', ', @$is_frags ),

                    #__tableattrs => 'style="margin-top: 30px"',
                    "Fragment Lengths Match Score" =>
                      sprintf( "%.2f", $match_score ),
                );
                info_table_html(
                    __border                => 0,
                    'Restriction Fragments' => <<EOHTML,
<table><tr><td>$gel_img</td><td valign="middle">$frag_listing</td></tr></table>
EOHTML
                );
            }
            else {
                my $frag_listing = info_table_html(
                    __sub    => 1,
                    __border => 0,
                    "$enzyme <i>in vitro</i> ("
                      . scalar(@$iv_frags)
                      . ')' => join( ', ', @$iv_frags ),
                );
                info_table_html(
                    __border                => 0,
                    'Restriction Fragments' => <<EOHTML,
<table><tr><td>$gel_img</td><td valign="middle">$frag_listing</td></tr></table>

EOHTML
                );
            }
        } @iv_frags;
    };

    ### if this clone has a sequence, check it for various kinds of
    ### badness
    my $warnings_html = do {
        if ($latest_seq) {
            my @warnings;
            unless ($is_finished) {
                push @warnings, 'sequence is not finished to HTGS3';
            }

            my $feature_query = $dbh->prepare(<<EOQ);
select fl.fmin, fl.fmax, f1.name
from clone_feature
join feature f2 using(feature_id)
join featureloc fl on f2.feature_id=srcfeature_id
join feature f1 on fl.feature_id=f1.feature_id
join feature_dbxref fd on fl.feature_id=fd.feature_id
where fd.dbxref_id=(select dbxref_id from dbxref where accession=?)
  and clone_id = ?
EOQ

            #given a list of 2-element arrayrefs which are ranges,
            #find the sum number of bases they cover, *not counting overlaps*
            sub sum_ranges {
                sum
                  map {    #warn "got range ".$_->start.", ".$_->end."\n";
                    $_->length()
                  } Bio::Range->disconnected_ranges(
                    map {
                        Bio::Range->new( -start => $_->[0], -end => $_->[1] )
                      } @_
                  );
            }

            #check for too much vector in the sequence
            $feature_query->execute( 'Cross_match_vector', $clone->clone_id );
            my $matches = $feature_query->fetchall_arrayref;
            if ( $matches && @$matches ) {
                if ( sum_ranges(@$matches) / $seqlen > 0.1 ) {
                    push @warnings,
                      "more than 10% of sequence matches cloning vector";
                }
                if ($is_finished) {
                    my $seq_middle = Bio::Range->new(
                        -start => int( 0.1 * $seqlen ),
                        -end   => int( 0.9 * $seqlen )
                    );

      #convert the vector matches to ranges so we can work with them more easily
                    my @vector_ranges = map {
                        Bio::Range->new(
                            -start => $_->[0] + 1,
                            -end   => $_->[1]
                          )
                    } @$matches;
                    if ( any( map { $_->overlaps($seq_middle) } @vector_ranges )
                      )
                    {
                        push @warnings,
                          "vector found in middle 80% of sequence";
                    }
                }
            }

            #check for E.coli blast hits in the sequence
            $feature_query->execute( 'BLAST_E_coli_K12', $clone->clone_id );
            $matches = $feature_query->fetchall_arrayref;
            if ( $matches && @$matches ) {
                push @warnings,
                  "full sequence contains matches to E. coli K12 genome";
            }

            #check for tomato chloroplast hits
            $feature_query->execute( 'BLAST_tomato_chloroplast',
                $clone->clone_id );
            $matches = $feature_query->fetchall_arrayref;
            if ( $matches && @$matches ) {
                push @warnings,
                  "full sequence contains matches to Tomato chloroplast genome";
            }

            #check for hits to other bacs
            $feature_query->execute( 'BLAST_tomato_bacs', $clone->clone_id );
            $matches = $feature_query->fetchall_arrayref;
            $matches = [
                grep {
                    index( $_->[2], $clone->clone_name_with_chromosome ) != 0
                  } @$matches
            ];
            if (   $matches
                && @$matches
                && sum_ranges(@$matches) / $seqlen > 0.2 )
            {
                push @warnings,
"more than 20% of full sequence matches other tomato genomic clones";
            }

            #check for the low restriction match score flag
            if ($low_restriction_match_score) {
                push @warnings,
"poor correspondence with <i>in vitro</i> restriction fragments<br/>(match score below $restriction_match_threshold)";
            }

            #check this sequence's length vs. estimated length
            if (
                $clone->estimated_length
                and ( my $pdiff =
                    abs( $seqlen - $clone->estimated_length ) /
                    $clone->estimated_length ) > 0.4
              )
            {
                push @warnings,
                  sprintf(
"sequence length %s is %0.1f%% different from estimated length %s",
                    commify_number($seqlen),
                    $pdiff * 100,
                    commify_number( $clone->estimated_length )
                  );
            }

            if (@warnings) {
                "<ul>\n"
                  . join( '', map { "<li>$_</li>\n" } @warnings )
                  . "</ul>\n";
            }

        }
    };

    my $htgs_phase_html = (
        'none',
        '1 - fragmented, unordered',
        '2 - fragmented, ordered',
        '3 - finished'
      )[ $clone->seqprops->{htgs_phase} ]
      || 'not sequenced';
    my $sequenced_by_html = do {
        if ( my $seq_shortname = $clone->seqprops->{sequenced_by} ) {

            #look up the organization for that shortname
            my $matching_orgs = $dbh->selectcol_arrayref(
'select name from sgn_people.sp_organization where shortname = ?',
                undef, $seq_shortname
            );
            if ( @$matching_orgs == 1 ) {
                $matching_orgs->[0];
            }
            else {
                qq|<span class="ghosted">$seq_shortname</span>|;
            }
        }
        elsif ( my $ul = $clone->seqprops->{upload_account_name} ) {
            "Uploaded by account '$ul'";
        }
        else {
            '<span class="ghosted">not recorded</span>';
        }
    };

    my $agp_map_link = do {
        if ( my @agp_pos = agp_positions($clone) ) {
            my $url =
                "/cview/view_chromosome.pl?map_id=agp&hilite="
              . $clone->clone_name
              . "&chr_nr="
              . $agp_pos[0][0];
            qq|<a href="$url">View on AGP map chromosome $agp_pos[0][0]</a>|;
        }
        else {
            '';
        }
    };

    return $sequencing_project_html . info_table_html(
        'Sequencing Project' => $self->_clone_seq_project_name($clone),
        'Sequencing Status'  => $sequencing_status_html,
        'Full Sequence'      => $sequence_info,
        Warnings => $warnings_html || qq|<span class="ghosted">none</span>|,
        (
            $self->_is_tomato($clone)
            ? ( 'Chromosome Assembly' => $agp_map_link
                  || 'this clone is not part of a chromosome assembly' )
            : ()
        ),
        'HTGS phase'              => $htgs_phase_html,
        'Sequencing Organization' => $sequenced_by_html,
        'End Sequences'           => do {

            #get BAC end data
            if ( my @chromats = $clone->chromat_objects ) {
                join '', map { "$_\n" } (
                    '<ul style="margin: 0; padding-left: 2em">',
                    (
                        map {
                            '<li>'
                              . $_->read_link_html(
                                $link_pages{read_info_page} )
                              . '</li>'
                          } @chromats
                    ),
                    '</ul>',
                );
            }
            else {
                '<span class="ghosted">None</span>';
            }
        },
        FTP          => $ftp_link,
        __border     => 0,
        __multicol   => 2,
        __tableattrs => 'width="100%"',
    ) . $restriction_frags_html;

}

sub sequencing_project_html {
    my ( $user_type, $chr, $clone ) = @_;

    my ( undef, $organism, $accession ) =
      $clone->library_object->accession_name;
    return '' unless $organism =~ /lycopersicum/i;

    return do {
        if ( $chr eq 'unmapped' ) {
qq|<div class="specialnote">This clone is registered to be sequenced, but has not been successfully mapped to any chromosome.</div>|;
        }
        elsif ($chr) {
qq|This clone is being sequenced by the Chromosome $chr Sequencing Project. (<a href="/about/tomato_sequencing.pl">View projects</a>)|;
        }
        else {
            "This clone is not assigned to any sequencing project.\n";
        }
      }
      . '<br />' 
      . do {
        if ( $user_type eq 'curator' or $user_type eq 'sequencer' ) {
            my $q = CXGN::Genomic::Search::Clone->new->new_query;
            $q->clone_id( '=?', $clone->clone_id );
            my $clone_reg_link = 'clone_reg.pl?' . $q->to_query_string;
qq| To change this clone's sequencing project assignment or other registry information, use the <a href="$clone_reg_link">Clone Registry Editor</a>.|;
        }
        else {
qq|<span class="ghosted">Log in as a curator or sequencer to edit this clone's registry information.</span>|;
        }
      }
}

sub render_tomato_bac_annot_download {
    my ( $c, $clone ) = @_;

    #look at the keys in the sequencing_files hash to figure out the
    #analysis formats we have available.
    my %sequencing_files =
      CXGN::TomatoGenome::BACPublish::sequencing_files( $clone,
        $c->config->{'ftpsite_root'} );

    my @formats =
      distinct( grep { $_ }
          map { my ($k) = /_([^_]+)$/; $k } keys %sequencing_files );

    my @available_analyses =
      grep {    #find analyses that have all their files available
        my $a = $_ eq 'all' ? '' : $_ . '_';
        all( map { $sequencing_files{ $a . $_ } } @formats )
      } 'all', CXGN::TomatoGenome::BACSubmission->list_analyses;

    if ( @formats && @available_analyses ) {
        my $set_select = simple_selectbox_html(
            choices => \@available_analyses,
            name    => 'set',
            id      => 'annot_set_selector',
        );
        my $type_select = simple_selectbox_html(
            choices => \@formats,
            name    => 'format',
            id      => 'annot_format_selector',
        );
        my $id = $clone->clone_id;

        return <<EOHTML
<form name="clone_annot_download" method="GET" action="/genomic/clone/$id/annotation/download">
<table><tr><td><label for="annot_set_selector">Analysis:</label></td><td>$set_select</td></tr>
       <tr><td><label for="annot_format_selector">Format:</label></td><td>$type_select <input type="hidden" name="id" value="$id" /><input type="submit" value="Download" /></td></tr>
       <tr><td>&nbsp;</td></tr>
</table>
</form>
EOHTML
    }
    else {
        return qq|<span class="ghosted">temporarily unavailable</span>|;
    }

}    # end prelim annot section

# NOTE: this function used to be in CXGN::Genomic::Clone
# =head2 agp_positions

#   Usage: my $pos = $clone->agp_position
#   Desc : get this clone's position in its chromosome's AGP file,
#          or undef if it's not in there
#   Args : none
#   Ret  : nothing if not in AGP file, otherwise a list of
#          [ chromonum, global start, global end, local start, local end, length ]

# =cut
sub agp_positions {
    my ($clone) = @_;

    my $chr = $clone->chromosome_num;
    $chr += 0;
    $chr >= 1 && $chr <= 12
      or return;

    my ( undef, $agp_file ) =
      CXGN::TomatoGenome::BACPublish::tpf_agp_files($chr);

    return unless $agp_file;
    unless ( -r $agp_file ) {
        warn "agp file $agp_file not readable";
        return;
    }

    my $name = $clone->clone_name_with_chromosome
      or return;

    open my $agp, '<', $agp_file
      or die "$! reading $agp_file";

    return map {
        my @fields = split;
        my @record = map $_ + 0, ( $chr, @fields[ 1, 2, 6, 7 ] );
        $record[5] = $record[2] - $record[1] + 1;
        \@record
      }
      grep /$name/,
      <$agp>;
}

sub render_old_arizona_fpc {
    my ( $dbh, $clone ) = @_;

    my $clone_id = $clone->clone_id;

    my $map_id = CXGN::DB::Physical::get_current_map_id();

    # Get FPC Contigging data.
    my ( $fpc_version, $fpc_date ) =
      CXGN::DB::Physical::get_current_fpc_version_and_date($dbh);
    my $fpc_sth = $dbh->prepare_cached(<<EOQ);
      SELECT  bc.bac_contig_id,
              bc.contig_name,
      	bap.plausible
      FROM physical.bac_associations AS ba
      INNER JOIN physical.ba_plausibility AS bap
        ON bap.bac_assoc_id=ba.bac_assoc_id
      INNER JOIN physical.bac_contigs AS bc
        ON ba.bac_contig_id=bc.bac_contig_id
      WHERE ba.bac_id=? AND bc.fpc_version=?
EOQ

    $fpc_sth->execute( $clone_id, $fpc_version );
    my $contig_sth = $dbh->prepare_cached(<<EOQ);
      SELECT ba.bac_id
      FROM physical.bac_associations AS ba
      INNER JOIN physical.ba_plausibility AS bap
         USING (bac_assoc_id)
      INNER JOIN physical.bacs AS b
         ON ba.bac_id=b.bac_id
      WHERE ba.bac_contig_id=?
         AND bap.map_id=?
EOQ

    my @coherent_ctgs;
    my @incoherent_ctgs;
    while ( my ( $ctg_id, $contig, $coherent ) = $fpc_sth->fetchrow_array ) {
        if ($coherent) {
            my @ctg_members;
            $contig_sth->execute( $ctg_id, $map_id );
            while ( my ($thisbacid) = $contig_sth->fetchrow_array ) {
                my $thisbac     = CXGN::Genomic::Clone->retrieve($thisbacid);
                my $thisbacname = $thisbac->clone_name_with_chromosome
                  || $thisbac->clone_name;
                if ( $thisbacid == $clone_id ) {
                    push @ctg_members,
                      qq{<b><span style="color:red">$thisbacname</span></b>};
                }
                else {
                    push @ctg_members,
qq{<a href="$link_pages{bac_page}$thisbacid">$thisbacname</a>};
                }
            }
            push @coherent_ctgs,
              qq{<b>$contig :</b> [<span style="color: red">coherent</span>], }
              . ( scalar @ctg_members )
              . qq{ members: <br />\n};
            push @coherent_ctgs, "" . join( ",\n", @ctg_members ) . "<br />\n";
        }
        else {
            my @ctg_members;
            $contig_sth->execute( $ctg_id, $map_id );
            while ( my ($thisbacid) = $contig_sth->fetchrow_array ) {
                ( $thisbacid == $clone_id ) && next;
                my $thisbac     = CXGN::Genomic::Clone->retrieve($thisbacid);
                my $thisbacname = $thisbac->clone_name_with_chromosome
                  || $thisbac->clone_name;
                push @ctg_members,
qq{<a href="$link_pages{bac_page}$thisbacid">$thisbacname</a>};
            }
            push @incoherent_ctgs,
qq{<b>$contig :</b> [<span style="color: red">incoherent</span>], }
              . ( scalar @ctg_members )
              . qq{ members:<br />\n};
            push @incoherent_ctgs,
              "" . join( ",\n", @ctg_members ) . "<br />\n";
        }
    }
    $fpc_sth->finish;
    $contig_sth->finish;

    if ( @coherent_ctgs || @incoherent_ctgs ) {
        return join "\n",
          (
            '<dt>Tomato FPC (AGI 2005)</dt>',
            '<dd>', @coherent_ctgs, @incoherent_ctgs, '</dd>',
          );
    }
    else {
        return
'<dt class="ghosted">not present in Tomato FPC (AGI 2005)</dt><dd class="ghosted"></dd>';
    }
}

sub render_overgo {
    my ( $clone, $dbh ) = @_;

    # Get Overgo Plating data.
    my $map_id = CXGN::DB::Physical::get_current_map_id();

    my $overgo_version = CXGN::DB::Physical::get_current_overgo_version($dbh);
    my $op_sth         = $dbh->prepare(
        "SELECT oap.plausible,
                                   pm.overgo_plate_row,
				   pm.overgo_plate_col,
				   marker_id,
                                   map_id,
				   op.plate_number
			    FROM  physical.overgo_associations AS oa
                            INNER JOIN physical.oa_plausibility AS oap
                                  ON oap.overgo_assoc_id=oa.overgo_assoc_id
			    INNER JOIN physical.probe_markers AS pm
				  ON oa.overgo_probe_id=pm.overgo_probe_id
			    INNER JOIN physical.overgo_plates AS op
				  ON pm.overgo_plate_id=op.plate_id
			    WHERE oa.bac_id=?
                                  AND oa.overgo_version=?
                                  AND oap.map_id=?
    "
    );
    $op_sth->execute( $clone->clone_id, $overgo_version, $map_id );

    #format the overgo plating data into html
    sub fmt_overgo {
        my ( $dbh, $plausible, $row, $col, $marker_id, $map_id, $plateno ) = @_;
        my ( $map_name, $marker_name ) = ( '', '' );
        if ( my $marker = CXGN::Marker->new( $dbh, $marker_id ) ) {
            $marker_name = $marker->name_that_marker();
        }
        if ( my $map = CXGN::Map->new( $dbh, { map_id => $map_id } ) ) {
            $map_name = $map->short_name();
        }
        [
            qq|<a href="$link_pages{marker_page}$marker_id">$marker_name</a>|,
            qq|<a href="$link_pages{map_page}$map_id">$map_name</a>|,
qq|<a href="$link_pages{plate_design_page}$plateno&highlightwell=$row$col">plate $plateno</a>|,
qq|<a href="$link_pages{plate_design_page}$plateno&highlightwell=$row$col">$row$col</a>|
        ];
    }
    my @matches = @{ $op_sth->fetchall_arrayref };
    my @plausible_matches =
      map { fmt_overgo( $dbh, @$_ ) } grep { $_->[0] } @matches;
    my @conflicted_matches =
      map { fmt_overgo( $dbh, @$_ ) } grep { !$_->[0] } @matches;

    #output overgo information
    my @matches_headings = qw/Probe Map Plate Well/;
    my $plausible_matches_html =
      @plausible_matches
      ? columnar_table_html(
        headings => \@matches_headings,
        data     => \@plausible_matches,
        __border => 1,
      )
      : undef;
    my $conflicted_matches_html =
      @conflicted_matches
      ? columnar_table_html(
        headings => \@matches_headings,
        data     => \@conflicted_matches,
        __border => 1,
      )
      : undef;
    if ( $plausible_matches_html || $conflicted_matches_html ) {
        info_table_html(
            'Plausible matches' => $plausible_matches_html
              || '<span class="ghosted">None</span>',
            'Conflicted matches' => $conflicted_matches_html
              || '<span class="ghosted">None</span>',
            'Additional Info' =>
qq|<a href="$link_pages{overgo_report_page}">Overgo Plating Progress Report</a>|,
            __border   => 0,
            __multicol => 2,
        );
    }
    else {
        '';
    }
}

sub render_computational_associations {
    my ( $clone, $dbh ) = @_;
    my $cas = $dbh->selectall_arrayref( <<EOSQL, undef, $clone->clone_id );
select marker_id,e_value,identity,score,parameters
from physical.computational_associations
where clone_id = ?
EOSQL

    if ( $cas and @$cas ) {

        #alter the data to make it more suitable for display
        foreach my $r (@$cas) {

            #change the marker ID to an html link
            $r->[0] = qq|<a href="$link_pages{marker_page}$r->[0]">|
              . CXGN::Marker->new( $dbh, $r->[0] )->name_that_marker . '</a>';
            $r->[3] = sprintf( '%0.2f', $r->[3] );
        }

        columnar_table_html(
            headings => [ 'Marker', 'Evalue', 'Identity %', 'Score', 'Params' ],
            data     => $cas,
        );
    }
    else {
        '';
    }
}
