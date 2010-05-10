use strict;
use warnings;
use CXGN::Page;

use CXGN::Apache::Error;
use CXGN::DB::Connection;
use CXGN::People::PageComment;
use CXGN::People;
use CXGN::Contact;
use CXGN::Page::FormattingHelpers qw(
        info_section_html
        page_title_html
        columnar_table_html
        info_table_html
        html_optional_show
        html_alternate_show
        tooltipped_text
      );
use CXGN::Page::Widgets qw / collapser /;
use CXGN::Phenome::Locus;
use CXGN::Phenome::Locus::LinkageGroup;

use CXGN::Cview::ChrMarkerImage;
use CXGN::Cview::MapFactory;
use CXGN::Marker;
use CXGN::Cview::Marker::RangeMarker;
use CXGN::Map;

use CXGN::Chado::CV;
use CXGN::Chado::Feature;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;


use CXGN::Sunshine::Browser;
use CXGN::Tools::Identifiers qw/parse_identifier/;
use CXGN::Tools::List qw/distinct/;

use CXGN::Phenome::Locus::LocusPage;
use SGN::Image;
use HTML::Entities;

my $d = CXGN::Debug->new();
##$d->set_debug( 1 );


my $page= CXGN::Page->new("Locus display", "Naama");
my $dbh=$page->get_dbh();

my $time = time();
$d->d("start time = $time ! \n");

my %args = $page->cgi_params();
my $locus_id = $args{locus_id};

my $person_id = CXGN::Login->new($dbh)->has_session();
my $user = CXGN::People::Person->new($dbh, $person_id);
my $user_type = $user->get_user_type();
my $script = "/phenome/locus_display.pl?locus_id=$locus_id";

unless ( ( $locus_id =~ m /^\d+$/ ) || ($args{action} eq 'new' && !$locus_id) ) {
    $c->throw(is_error=>0,
	      message=>"No locus exists for identifier $locus_id",
	);
    $d->d("No locus exists for identifier $locus_id");
}

my $locus= CXGN::Phenome::Locus->new( $dbh, $locus_id  );
if ( $locus->get_obsolete() eq 't' && $user_type ne 'curator' )
{
    $d->d("locus is obsolete!!" );
    
    $c->throw(is_error=>0, 
	      title => 'Obsolete locus',
	      message=>"Locus $locus_id is obsolete!",
	      developer_message => 'only curators can see obsolete loci',
	      notify => 0,   #< does not send an error email
	);
    #$page->message_page("Locus $locus_id is obsolete!");
}


my $locus_name = $locus->get_locus_name();
my $organism   = $locus->get_common_name();

$page->jsan_use("CXGN.Phenome.Tools");
$page->jsan_use("CXGN.Phenome.Locus");
$page->jsan_use("MochiKit.DOM");
$page->jsan_use("Prototype");
$page->jsan_use("jQuery");
$page->jsan_use("thickbox");
$page->jsan_use("MochiKit.Async");
$page->jsan_use("CXGN.Sunshine.NetworkBrowser");
$page->jsan_use("CXGN.Phenome.Locus.LocusPage");
$page->jsan_use("CXGN.Page.Form.JSFormPage");

#used to show certain elements to only the proper users

my @owners   = $locus->get_owners();

my $action = $args{action};

if ( !$locus->get_locus_id() && $action ne 'new' && $action ne 'store' ) {
    $c->throw(is_error=>0, message=>'No locus exists for this identifier',);
    $d->d('No locus exists for this identifier');
    #$page->message_page("No locus exists for this identifier");
}

$page->header("SGN $organism locus: $locus_name");

print page_title_html("$organism \t'$locus_name'\n");

print CXGN::Phenome::Locus::LocusPage::initialize($locus_id);

$d->d("!!!Printing page title :  " . ( time() - $time ) . "\n");
####################################################
#get all dbxref  annotations: pubmed, ncbi sequences, GO, PO, tgrc link
####################################################
my @allele_objs = $locus->get_alleles();    #array of allele objects
my ( $tgrc, $pubs, $pub_count, $genbank, $gb_count, $onto_ref ) =
    get_dbxref_info($locus, @allele_objs);

$d->d( "!!!Got all dbxrefs! :  " . ( time() - $time ) . "\n");

##############################
    #display locus details section
#############################
my $curator_html;
my ( $synonyms, $symbol, $symbol_link, $activity, $description, $lg_name,
     $arm, $locus_details );
my $editor_note =
    qq |<a href="/phenome/editors_note.pl">Note to Editors</a>|;
my $guide_html =
    qq|<a href="http://docs.google.com/View?docid=ddhncntn_0cz2wj6">Annotation guidelines</a>|;

my $locus_html= qq| <table width="100%"><tr><td>|
    . CXGN::Phenome::Locus::LocusPage::init_locus_form($locus_id);
#Only show if you are a curator or the object owner and there is no registry already assocaited with the locus
if (
    (
     $user_type eq 'curator'
	 || grep { /^$person_id$/ } @owners
    )
    && !( $locus->get_associated_registry() )
    )
{
    if ($locus_name) { $locus_html .= associate_registry($locus, $person_id); }
    else {
	$curator_html .=
	    qq |<span class = "ghosted"> [Associate registry name]</span> |;
    }
}

#merge locus form
if ( $user_type eq 'curator' ) {
    $curator_html .= "<br />" . merge_locus($locus, $person_id);
}

my $locus_synonym_count = scalar( $locus->get_locus_aliases('f', 'f') ) || "";
$locus_html .=
    qq { <br /><br /><b>Locus synonyms</b> <b>$locus_synonym_count:</b> };

foreach my $synonym ( $locus->get_locus_aliases('f','f') ) {
    $locus_html .= $synonym->get_locus_alias() . "  ";
}

if ($locus_name) {
    $locus_html .=
	qq|<a href="locus_synonym.pl?locus_id=$locus_id&amp;action=new">[Add/Remove]</a><br />|;
    
    $locus_html .= "<br />" . $tgrc;
    
    #print editors info
    $locus_html .= print_locus_editor_info($locus) . "<br>";
    
    #change ownership:
    if ( $user_type eq 'curator' ) {
	$curator_html .= assign_owner($locus);
    }
    if (   ( !( grep { $_ =~ /^$person_id$/ } @owners ) )
	   && ( $user_type ne 'curator' ) )
    {
	
	$locus_html .=
	    qq|<a href="claim_locus_ownership.pl?locus_id=$locus_id&amp;action=confirm"> [Request editor privileges]</a><br /><br />|;
    }
    
    my $created_date = $locus->get_create_date();
    $created_date = substr $created_date, 0, 10;
    my $modified_date = $locus->get_modification_date() || "";
    $modified_date = substr $modified_date, 0, 10;
    
    my $updated_by = $locus->get_updated_by();
    my $updated =
	CXGN::People::Person->new( $locus->get_dbh(), $updated_by );
    my $u_first_name = $updated->get_first_name();
    my $u_last_name  = $updated->get_last_name();
    $locus_html .= qq |Created on: $created_date |;
    if ($modified_date) {
	$locus_html .=
	    qq |  Last updated on: $modified_date  by  <a href="/solpeople/personal-info.pl?sp_person_id=$updated_by">$u_first_name $u_last_name</a><br />|;
    }
    
    #build a chromosome, map/s and marker/s objects
    $locus_html .= get_location($locus);
}

my $name = $locus->get_associated_registry();
if ($name) {
    $locus_html .= "This locus is associated with registry name: $name<br />";
}

##############history ############

if ( $user_type eq 'curator'
     || grep { /^$person_id$/ } @owners )
{
    my $history_data = print_locus_history($locus) || "";
    $locus_html .= $history_data;
}
my $locus_xml = $locus_id ? qq |<a href = "generic_gene_page.pl?locus_id=$locus_id">Download GMOD XML</a>|
    : qq |<span class="ghosted">Download GMOD XML</span>|;

    #print locus details section
    print info_section_html(
        title    => 'Locus details',
        subtitle => $locus_xml . " |" . " "
	. $editor_note . " " . "|" . " "
	. $guide_html,
        contents => $locus_html,
    );
    if ($curator_html) {
        print info_section_html(
            title       => 'Curator tools',
            subtitle    => "",
            contents    => $curator_html,
            collapsible => 1,
            collapsed   => 1,
        );
    }
    print STDERR "!!!Printing locus_details :  " . ( time() - $time ) . "\n";

##########
## Notes and Figures
##########
    #
    my $figure_html     = "";
    my $m_figure_html   = "";
    my $figure_subtitle = "";
    my $figures_count;
    my @more_is;
    

    if (
        $locus_name
        && (   $user_type eq 'submitter'
            || $user_type eq 'curator'
            || $user_type eq 'sequencer' )
      )
    {
        $figure_subtitle .= associated_figures($locus, $person_id);
    }
    else {
        $figure_subtitle .=
          qq|<span class= "ghosted">[Add notes, figures or images]</span> |;
    }

    my @figures = $locus->get_figure_ids();

    if (@figures) {    # don't display anything for empty list of figures
        $figure_html .= qq|<table cellpadding="5">|;
        foreach my $figure_id (@figures) {
            $figures_count++;
	    my $figure= SGN::Image->new($locus->get_dbh(), $figure_id);
	    my $figure_name        = $figure->get_name();
            my $figure_description = $figure->get_description();
            my $figure_img  = $figure->get_image_url("medium");
            my $small_image = $figure->get_image_url("thumbnail");
            my $image_page  = "/image/index.pl?image_id=$figure_id";
	    
            my $thickbox =
qq|<a href="$figure_img"  title="<a href=$image_page>Go to image page ($figure_name)</a>" class="thickbox" rel="gallery-figures"><img src="$small_image" alt="$figure_description" /></a> |;
            my $fhtml =
                qq|<tr><td width=120>|
              . $thickbox
              . $figure_name
              . "</td><td>"
              . $figure_description
              . "</td></tr>";
            if ( $figures_count < 3 ) { $figure_html .= $fhtml; }
            else {
                push @more_is, $fhtml;
            }    #more than 3 figures- show these in a hidden div
        }
        $figure_html .= "</table>";  #close the table tag or the first 3 figures
    }
    $m_figure_html .=
      "<table cellpadding=5>";  #open table tag for the hidden figures #4 and on
    my $more = scalar(@more_is);
    foreach (@more_is) { $m_figure_html .= $_; }

    $m_figure_html .= "</table>";    #close tabletag for the hidden figures
    my $more_images;
    if (@more_is) {    #html_optional_show if there are more than 3 figures
        $more_images = html_optional_show(
            "Images",
            "<b>See $more more figures...</b>",
            qq| $m_figure_html |,
            0,                        #< do not show by default
            'abstract_optional_show', #< don't use the default button-like style
        );
    }
    print info_section_html(
        title       => "Notes and figures (" . scalar(@figures) . ")",
        subtitle    => $figure_subtitle,
        contents    => $figure_html . $more_images,
        collapsible => 1,
        collapsed   => 1,
    );
    print STDERR "!!!Printing notes and figures :  "
      . ( time() - $time ) . "\n";

#################################
    #display individuals section
#################################
    my $individuals_html = "";
    my $ind_subtitle     = "";
    if (
        $locus_name
        && (   $user_type eq 'curator'
            || $user_type eq 'submitter'
            || $user_type eq 'sequencer' )
      )
    {
        $ind_subtitle .=
qq| <a href="javascript:Tools.toggleContent('associateIndividualForm', 'locus_accessions')">[Associate accession]</a> |;
        $individuals_html = associate_individual($locus, $person_id);
    }
    else {
        $ind_subtitle .=
          qq|<span class= "ghosted">[Associate accession]</span> |;
    }
    my ( $html, $ind_count ) = get_individuals_html($locus, $user_type);
    $individuals_html .= $html;

    print info_section_html(
        title       => "Accessions and images  ($ind_count)",
        subtitle    => $ind_subtitle,
        contents    => $individuals_html,
        id          => "locus_accessions",
        collapsible => 1,
        collapsed   => 1,
    );
    print STDERR "!!!Printing individuas section :  "
      . ( time() - $time ) . "\n";

#################################
    #display alleles section
#################################

    my $allele_count = scalar(@allele_objs);

    #map the allele objects to an array ref of the alleles data
    my @allele_data;
    my $allele_data;
    my $allele_subtitle;
    if (
        $locus_name
        && (   $user_type eq 'submitter'
            || $user_type eq 'curator'
            || $user_type eq 'sequencer' )
      )
    {
        $allele_subtitle .=
qq { <a href="allele.pl?locus_id=$locus_id&amp;action=new">[Add new allele]</a>};
    }
    else {
        $allele_subtitle .=
          qq | <span class="ghosted">[Add new Allele]</span> |;
    }

    foreach my $a (@allele_objs) {

        my $allele_id = $a->{allele_id};

        my $allele_synonyms;
        my @allele_aliases = $a->get_allele_aliases();
        foreach my $a_synonym (@allele_aliases) {
            $allele_synonyms .= $a_synonym->get_allele_alias() . "  ";
        }
        if ( !$allele_synonyms ) { $allele_synonyms = "[add new]"; }
        my $allele_synonym_link =
qq |<a href= "allele_synonym.pl?allele_id=$allele_id&amp;action=new">$allele_synonyms</a> |;
        my $allele_edit_link = get_allele_edit_links($a, $user);
        my $phenotype        = $a->get_allele_phenotype();
        my @individuals      = $a->get_individuals();
        my $individual_link  = "";
        my $ind_count        = scalar(@individuals);

        $individual_link .=
qq|<a href="allele.pl?action=view&amp;allele_id=$allele_id">$ind_count </a>|;

        push @allele_data,
          [
            map { $_ } (
                "<i>" . $a->get_allele_symbol . "</i>",
                $a->get_allele_name,
                $allele_synonym_link,
qq|<div align="left"><a href="allele.pl?action=view&amp;allele_id=$allele_id"> |
                  . $phenotype
                  . "</a></div>",
                $individual_link,
                $allele_edit_link,
            )
          ];

    }
    if (@allele_data) {

        $allele_data .= columnar_table_html(
            headings => [
                'Allele symbol', 'Allele name',
                'Synonyms',      'Phenotype',
                'Accessions',
            ],
            data         => \@allele_data,
            __alt_freq   => 2,
            __alt_width  => 1,
            __alt_offset => 3,
        );
    }

    print info_section_html(
        title       => "Known alleles ($allele_count)",
        subtitle    => $allele_subtitle,
        contents    => $allele_data,
        collapsible => 1,
        collapsed   => 1,
    );
    print STDERR "!!!Printing alleles :  " . ( time() - $time ) . "\n";



    ###########################               ASSOCIATED LOCI
    #my @locus_groups= $locus->get_locusgroups();
    #my $direction;
    my $al_count = $locus->count_associated_loci();

    my $associated_locus_sub;
    my $associate_locus_form;
    if (
        (
               $user_type eq 'curator'
            || $user_type eq 'submitter'
            || $user_type eq 'sequencer'
        )
      )
    {

        if ($locus_name) {
            $associated_locus_sub .=
		qq |<a href="javascript:Tools.toggleContent('associateLocusForm', 'locus2locus');Tools.getOrganisms()">[Associate new locus]</a> |;
            $associate_locus_form =
		CXGN::Phenome::Locus::LocusPage::associate_locus_form($locus_id);
        }
    }
else {
    $associated_locus_sub .=
	qq |<span class ="ghosted"> [Associate new locus] </span> |;
}

#printing associated loci section dynamically
my $dyn = CXGN::Phenome::Locus::LocusPage::include_locus_network();

print info_section_html(
    title       => "Associated loci ($al_count) ",
    subtitle    => $associated_locus_sub,
    contents    => $associate_locus_form . $dyn,
    id          => 'locus2locus',
    collapsible => 1,
    collapsed   => 1,
    );

$d->d( "!!!Printing locus2locus :  " . ( time() - $time ) . "\n");

##################  SUNSHINE BROWSER

my $locus2locus_graph =
    CXGN::Sunshine::Browser::include_on_page( 'locus', $locus_id );

my $networkbrowser_link =
    qq { View <b>$locus_name</b> relationships in the stand-alone <a href="/tools/networkbrowser/?type=locus&name=$locus_id">network browser</a>. Please note that this tool is a prototype.<br /><br /><br /> };

if ( $al_count > 0 ) {
    print info_section_html(
	title       => "Associated loci - graphical view [beta version]",
	contents    => $networkbrowser_link . $locus2locus_graph,
	id          => 'locus2locus_graph',
	collapsible => 1,
	collapsed   => 1,
        );
}
else {
    print info_section_html(
	title       => "Associated loci - graphical view",
	collapsible => 0,
	collapsed   => 1,
	id          => 'locus2locus_graph'
        );
    
}


#####################           UNIGENES AND SOLCYC

my @unigenes = $locus->get_unigenes();
my $unigene_count=0;
my $solcyc_count=0;
foreach (@unigenes) { 
    $unigene_count++ if $_->get_status eq 'C'; 
}

my $dyn_solcyc = CXGN::Phenome::Locus::LocusPage::include_solcyc_links();

print info_section_html(
    title       => "SolCyc links",
    contents    => $dyn_solcyc,
    id          => 'solcyc',
    collapsible => 1,
    collapsed   => 1,
    );
$d->d( "!!!Got SolCyc links :  " . ( time() - $time ) . "\n");

my $associate_unigene_form;
if (
    (
     $user_type eq 'curator'
     || $user_type eq 'submitter'
     || $user_type eq 'sequencer'
    )
    )
{
    if ($locus_name) { 
	$associate_unigene_form= qq|<a href="javascript:Tools.toggleContent('associateUnigeneForm', 'unigenes' )">[Associate new unigene]</a> |;
	$associate_unigene_form .= 
	    CXGN::Phenome::Locus::LocusPage::associate_unigene_form($locus_id);
    }
}
my $sequence_links;
if ($locus_name) {
    if ( !$genbank ) {
	$genbank = qq|<span class=\"ghosted\">none </span>|;
    }
    $genbank .=
	qq|<a href="/chado/add_feature.pl?type=locus&amp;type_id=$locus_id&amp;refering_page=$script&amp;action=new">[Associate new genbank sequence]</a><br />|;
    	
    
    #printing associated unigenes section dynamically
    my $dyn_unigenes = CXGN::Phenome::Locus::LocusPage::include_locus_unigenes();
    $d->d( "!!!Got unigenes :  " . ( time() - $time ) . "\n");

    $sequence_links = info_table_html(
	'SGN Unigenes'       => $dyn_unigenes . $associate_unigene_form,
	'GenBank Accessions' => $genbank,
        'Genome Matches'     => genomic_annots_html($locus),
        __border             => 0,
       );
}
my $seq_count = $gb_count + $unigene_count;
print info_section_html(
    title       => "Sequence annotations ($seq_count)",
    contents    => $sequence_links,
    id          => 'unigenes',
    collapsible => 1,
    collapsed   => 1,
    );
$d->d("!!!got sequence :  " . ( time() - $time ) . "\n");

##########literature ########################################
my ( $pub_links, $pub_subtitle );
if ($pubs) {
    $pub_links = info_table_html(
	"  "     => $pubs,
	__border => 0,
        );
}

if (
    $locus_name
    && (   $user_type eq 'curator'
	   || $user_type eq 'submitter'
	   || $user_type eq 'sequencer' )
    )
{
    $pub_subtitle .=
	qq|<a href="/chado/add_publication.pl?type=locus&amp;type_id=$locus_id&amp;refering_page=$script&amp;action=new"> [Associate publication] </a>|;
}
else {
    $pub_subtitle =
	qq|<span class=\"ghosted\">[Associate publication]</span>|;
}

my $disabled = "true";
if ($person_id) { $disabled = "false"; }
$pub_subtitle .=
    qq | <a href="javascript:void(0)"onclick="window.open('locus_pub_rank.pl?locus_id=$locus_id','publication_list','width=600,height=400,status=1,location=1,scrollbars=1')">[Matching publications]</a> |;

$d->d("!!!Printing pub links :  " . ( time() - $time ) . "\n");

print info_section_html(
    title       => "Literature annotation ($pub_count)",
    subtitle    => $pub_subtitle,
    contents    => $pub_links,
    collapsible => 1,
    collapsed   => 1,
    );

######################################## Ontology details ##############

my $ont_count = $locus->count_ontology_annotations(); #= scalar(@$onto_ref);

my $ontology_add_link = "";
my $ontology_subtitle;
if (
    (
     $user_type eq 'curator'
     || $user_type eq 'submitter'
     || $user_type eq 'sequencer'
    )
    )
{
    if ($locus_name) {
	$ontology_subtitle .=
	    qq|<a href="javascript:Tools.toggleContent('associateOntologyForm', 'locus_ontology')">[Add ontology annotations]</a> |;
	$ontology_add_link =
	    CXGN::Phenome::Locus::LocusPage::associate_ontology_form(
                $locus_id);
    }
}
else {
    $ontology_subtitle =
	qq |<span class = "ghosted"> [Add ontology annotations]</span> |;
}

my $dyn_ontology_info =
    CXGN::Phenome::Locus::LocusPage::include_locus_ontology();

print info_section_html(
    title       => "Ontology annotations ($ont_count)",
    subtitle    => $ontology_subtitle,
    contents    => $ontology_add_link . $dyn_ontology_info,
    id          => "locus_ontology",
    collapsible => 1,
    collapsed   => 1,
    );

$d->d( "!!!Printing ontology links! :  " . ( time() - $time ) . "\n");

####add page comments
if ($locus_name) {
    my $page_comment_obj =
	CXGN::People::PageComment->new( $locus->get_dbh(), "locus",
					$locus_id, $page->{request}->uri()."?".$page->{request}->args() );
    print $page_comment_obj->get_html();
}

$page->footer();



#########################################################
#functions used in the locus page:
##

sub empty_search {
    my ($page) = @_;
    
    #  $page->header();
    
    print <<EOF;
    
  <b>No locus was specified or this locus ID does not exist</b>

EOF

exit 0;
}

sub get_allele_edit_links {
    my $allele   = shift;
    my $user= shift;
    my $login_user_id    = $user->get_sp_person_id();
    my $locus    = $allele->get_locus();
    my $locus_id = $locus->get_locus_id();

    my $allele_edit_link = "";
   
    my $allele_id        = $allele->get_allele_id();
    if (   ( $allele->get_sp_person_id() == $login_user_id )
        || ( $user->get_user_type() eq 'curator' ) )
    {
        $allele_edit_link =
qq | <a href="allele.pl?action=edit&amp;allele_id=$allele_id">[Edit]</a> |;
    }
    else { $allele_edit_link = qq | <span class="ghosted">[Edit]</span> |; }
}

sub get_location {
    my $locus = shift;

    my $lg_name = $locus->get_linkage_group();
    my $arm     = $locus->get_lg_arm();
    my $location_html;
    my @locus_marker_objs =
	$locus->get_locus_markers();    #array of locus_marker objects
    foreach my $lmo (@locus_marker_objs) {
        my $marker_id = $lmo->get_marker_id();    #{marker_id};
        my $marker =
	    CXGN::Marker->new( $locus->get_dbh(), $marker_id )
	    ;                                       #a new marker object
	
        my $marker_name = $marker->name_that_marker();
        my $experiments = $marker->current_mapping_experiments();
        if (    $experiments
		and @{$experiments}
		and grep { $_->{location} } @{$experiments} )
        {
            my $count = 1;
            for my $experiment ( @{$experiments} ) {
                if ( my $loc = $experiment->{location} ) {
                    my $map_version_id = $loc->map_version_id();
                    my $lg_name        = $loc->lg_name();
		    
                    if ($map_version_id) {
                        my $map_factory =
			    CXGN::Cview::MapFactory->new( $locus->get_dbh() );
                        my $map = $map_factory->create(
                            { map_version_id => $map_version_id } );
                        my $map_version_id = $map->get_id();
                        my $map_name       = $map->get_short_name();
			
                        my $chromosome =
			    CXGN::Cview::ChrMarkerImage->new( "", 100, 150,
							      $locus->get_dbh(), $lg_name, $map, $marker_name );
                        my ( $image_path, $image_url ) =
			    $chromosome->get_image_filename();
                        my $chr_link =
			    qq|<img src="$image_url" usemap="#map$count" border="0" alt="" />|;
                        $chr_link .=
			    $chromosome->get_image_map("map$count") . "<br />";
                        $chr_link .= $map_name;
                        $count++;
			
                        $location_html .= "<td>" . $chr_link . "</td>";
                    }
                }
            }
        }
    }
    
#draw chromosome with marker-range for loci w/o associated marker, only a chromosome arm annotation
    if ( scalar(@locus_marker_objs) == 0 && $lg_name ) {
        my $organism = $locus->get_common_name();
        my %org_hash = (
            'Tomato'   => 9,    #F2 2000 map
            'Potato'   => 3,
            'Eggplant' => 6,
            'Pepper'   => 10
	    );
        my $map_id      = $org_hash{$organism};
        my $map_factory = CXGN::Cview::MapFactory->new( $locus->get_dbh() );
	
        my $map = $map_factory->create( { map_id => $map_id } );
        if ($map) {
            my $map_name = $map->get_short_name();
            my ( $north, $south, $center ) = $map->get_centromere($lg_name);
	    
            my $dummy_name;
            $dummy_name = "$arm arm" if $arm;
            my $chr_image =
		CXGN::Cview::ChrMarkerImage->new( "", 150, 150, $locus->get_dbh(),
						  $lg_name, $map, $dummy_name );
	    
            my ($chr) = $chr_image->get_chromosomes();
	    
            my $range_marker = CXGN::Cview::Marker::RangeMarker->new($chr);
	    
            my ( $offset, $nrange, $srange );
            if ( $arm eq 'short' ) {
                $offset = $nrange = $srange = $center / 2;
            }
            elsif ( $arm eq 'long' ) {
                my $stelomere = $chr->get_length();
                $offset = ( $center + $stelomere ) / 2;
                $nrange = $srange = ( $stelomere - $center ) / 2;
            }
	    
            $range_marker->set_offset($offset);    #center of north/south arm
            $range_marker->set_north_range($nrange);
            $range_marker->set_south_range($srange);
            $range_marker->set_marker_name($dummy_name);
            if ( !$dummy_name ) { $range_marker->hide_label(); }
	    
            #$range_marker->show_label();
            #}else {
            $range_marker->set_label_spacer(20);
	    
            $range_marker->get_label()->set_name($dummy_name);
            $range_marker->get_label->set_stacking_level(2);
	    
            $chr->add_marker($range_marker);
	    
            my ( $image_path, $image_url ) = $chr_image->get_image_filename();
            my $chr_link =
		qq|<img src="$image_url" usemap="#chr_arm_map" border="0" alt="" />|;
            $chr_link .= $chr_image->get_image_map("chr_arm_map") . "<br />";
            $chr_link .= $map_name;
	    
            $location_html .= "<td>" . $chr_link . "</td>";
        }
    }
    
    $location_html .= "</td></tr></table>";
    return $location_html;
}    #get_location

sub print_locus_history {
    my $locus = shift;
    my @history;
    my $history_data;
    my $print_history;
    my @history_objs = $locus->show_history();   #array of locus_history objects

    foreach my $h (@history_objs) {

        my $created_date = $h->get_create_date();
        $created_date = substr $created_date, 0, 10;

        my $history_id    = $h->{locus_history_id};
        my $updated_by_id = $h->{updated_by};
        my $updated =
	    CXGN::People::Person->new( $locus->get_dbh(), $updated_by_id );
        my $u_first_name = $updated->get_first_name();
        my $u_last_name  = $updated->get_last_name();
        my $up_person_link =
	    qq |<a href="/solpeople/personal-info.pl?sp_person_id=$updated_by_id">$u_first_name $u_last_name</a> ($created_date)|;
	
        push @history,
	[
	 map { $_ } (
	     $h->get_locus_symbol,  $h->get_locus_name,
	     $h->get_gene_activity, $h->get_description,
	     $h->get_linkage_group, $h->get_lg_arm,
	     $up_person_link,
	 )
	];
    }
    
    if (@history) {
	
        $history_data .= columnar_table_html(
            headings => [
                'Symbol',     'Name', 'Activity', 'Description',
                'Chromosome', 'Arm',  'Updated by',
            ],
            data         => \@history,
            __alt_freq   => 2,
            __alt_width  => 1,
            __alt_offset => 3,
	    );
        $print_history = html_optional_show(
            'locus_history',
            'Show locus history',
            qq|<div class="minorbox">$history_data</div> |,
	    );
    }
    
    return $print_history;
}    #print_locus_history

sub get_dbxref_info {
    my $locus      = shift;
    my $locus_name = $locus->get_locus_name();
    my %dbs        = $locus->get_dbxref_lists()
	;    #hash of arrays. keys=dbname values= dbxref objects
    my (@alleles) = @_;    #$locus->get_alleles();
    #add the allele dbxrefs to the locus dbxrefs hash...
    #This way the alleles associated publications and sequences are also printed on the locus page
    #it might be a good idea to pring a link to the allele next to each allele-derived annotation
    
    foreach my $a (@alleles) {
        my %a_dbs = $a->get_dbxref_lists();
	
        foreach my $a_db_name ( keys %a_dbs )
        {    #add allele_dbxrefs to the locus_dbxrefs list
            my %seen = ()
		; #hash for assisting filtering of duplicated dbxrefs (from allele annotation)
            foreach ( @{ $dbs{$a_db_name} } ) {
                $seen{ $_->[0]->get_accession() }++;
            }    #populate with the locus_dbxrefs
            foreach ( @{ $a_dbs{$a_db_name} } ) {    #and filter duplicates
                push @{ $dbs{$a_db_name} }, $_
		    unless $seen{ $_->[0]->get_accession() }++;
            }
        }
    }
    my ( $tgrc, $pubs, $genbank );
    ##tgrc
    foreach ( @{ $dbs{'tgrc'} } ) {
        if ( $_->[1] eq '0' ) {
            my $url       = $_->[0]->get_urlprefix() . $_->[0]->get_url();
            my $accession = $_->[0]->get_accession();
            $tgrc .=
		qq|$locus_name is a <a href="$url$accession" target="blank">TGRC gene</a><br />|;
        }
    }
    
    my $abs_count = 0;
    foreach ( @{ $dbs{'PMID'} } ) {
        if ( $_->[1] eq '0' ) {    #if the pub is not obsolete
            $pubs .= get_pub_info( $_->[0], 'PMID', $abs_count++ );
        }
    }
    foreach ( @{ $dbs{'SGN_ref'} } ) {
        $pubs .= get_pub_info( $_->[0], 'SGN_ref', $abs_count++ )
	    if $_->[1] eq '0';
    }
    
    my $gb_count = 0;
    foreach ( @{ $dbs{'DB:GenBank_GI'} } ) {
        if ( $_->[1] eq '0' ) {
            $gb_count++;
            my $url = $_->[0]->get_urlprefix() . $_->[0]->get_url();
            my $gb_accession =
		$locus->CXGN::Chado::Feature::get_feature_name_by_gi(
		    $_->[0]->get_accession() );
            my $description = $_->[0]->get_description();
            $genbank .=
		qq|<a href="$url$gb_accession" target="blank">$gb_accession</a> $description<br />|;
        }
    }
    my @ont_annot;
    
    # foreach ( @{$dbs{'GO'}}) { push @ont_annot, $_; }
    # foreach ( @{$dbs{'PO'}}) { push @ont_annot, $_; }
    # foreach ( @{$dbs{'SP'}}) { push @ont_annot, $_; }
    
    return ( $tgrc, $pubs, $abs_count, $genbank, $gb_count, \@ont_annot );
}

########################

sub abstract_view {
    my $pub           = shift;
    my $abs_count     = shift;
    my $abstract      = encode_entities($pub->get_abstract() );
    my $authors       = encode_entities($pub->get_authors_as_string() );
    my $journal       = $pub->get_series_name();
    my $pyear         = $pub->get_pyear();
    my $volume        = $pub->get_volume();
    my $issue         = $pub->get_issue();
    my $pages         = $pub->get_pages();
    my $abstract_view = html_optional_show(
        "abstracts$abs_count",
        'Show/hide abstract',
	qq|$abstract <b> <i>$authors.</i> $journal. $pyear. $volume($issue). $pages.</b>|,
        0,                           #< do not show by default
        'abstract_optional_show',    #< don't use the default button-like style
	);
    return $abstract_view;
}    #

sub get_pub_info {
    my ( $dbxref, $db, $count ) = @_;
    my $pub_info;
    my $accession = $dbxref->get_accession();
    my $pub_title = $dbxref->get_publication()->get_title();
    my $year= $dbxref->get_publication()->get_pyear();
    my $pub_id    = $dbxref->get_publication()->get_pub_id();
    my $abstract_view =
	abstract_view( $dbxref->get_publication(), $count );
    $pub_info =
	qq|<div><a href="/chado/publication.pl?pub_id=$pub_id" >$db:$accession</a> $pub_title ($year). $abstract_view </div> |;
    return $pub_info;
}    #

sub print_locus_editor_info {
    my $locus=shift;
    my $html   = "Locus editors: ";
    my @owners = $locus->get_owners();
   
    foreach my $id (@owners) {
        my $person = CXGN::People::Person->new( $locus->get_dbh(), $id );
	
        my $first_name = $person->get_first_name();
        my $last_name  = $person->get_last_name();
	if ($person->get_user_type() eq 'curator' && scalar(@owners) == 1  ) {
	    $html .= '<b>No editor assigned</b>';
	} else {
	    $html .=
		qq |<a href="/solpeople/personal-info.pl?sp_person_id=$id">$first_name $last_name</a>;|;
	}
    }
    chop $html;
    return $html;
}

sub get_individuals_html {
    my $locus        = shift;
    my $user_type=shift;
    my @individuals = $locus->get_individuals();

    my $html;
    my %imageHoA
      ; # hash of image arrays. Keys are individual_ids, values are arrays of image_ids
    my %individualHash;
    my %imageHash;
    my @no_image;
    my $more_html;
    my $more;    #count the number of accessions in the optional_show box
    my $count
      ; # a scalar for checking if there are accessions with images in the optional box

    if (@individuals) {
        $html      .= "<table>";
        $more_html .= "<table>";

        my %imageHoA
          ; # hash of image arrays. Keys are individual ids values are arrays of image ids
        foreach my $i (@individuals) {
            my $individual_id   = $i->get_individual_id();
            my $individual_name = $i->get_name();
            $individualHash{$individual_id} = $individual_name;

            my @images =
              $i->get_images();    #array of all associated image objects
            foreach my $image (@images) {
                my $image_id = $image->get_image_id();

                #my $img_src_tag= $image->get_img_src_tag("thumbnail");
                $imageHash{$image_id} = $image;
                push @{ $imageHoA{$individual_id} }, $image_id;
            }

            #if there are no associated images with this individual:
            if ( !@images ) { push @no_image, $individual_id; }
        }
        my $ind_count = 0;

        # Print the whole thing sorted by number of members and name.
        for
          my $individual_id ( sort { @{ $imageHoA{$b} } <=> @{ $imageHoA{$a} } }
            keys %imageHoA )
        {
            $ind_count++;
            my $individual_name = $individualHash{$individual_id};
            my $individual_obsolete_link =
              get_individual_obsolete_link($locus,$individual_id, $user_type);
            my $link =
qq|<a href="individual.pl?individual_id=$individual_id">$individual_name </a>  |;
            if ( $ind_count < 4 )
            { #print the first 3 individuals by default. The rest will be hidden
                $html .=
qq|<tr valign="top"><td>$link</td> <td> $individual_obsolete_link </td>|;
            }
            else {
                $count++;
                $more++;
                $more_html .=
                  qq|<tr><td>$link </td><td> $individual_obsolete_link</td> |;
            }

        #print only 5 images, if there are more write the number of total images
            my $image_count = ( $#{ $imageHoA{$individual_id} } );    #+1;
            if ( $image_count > 4 ) { $image_count = 4; }
            for my $i ( 0 .. $image_count ) {
                my $image_id = $imageHoA{$individual_id}[$i];
                #my $image    = $imageHash{$image_id};
                my $image = SGN::Image->new($locus->get_dbh(), $image_id);
                my $small_image  = $image->get_image_url("thumbnail");
                my $medium_image = $image->get_image_url("medium");
                my $image_page   = "/image/index.pl?image_id=$image_id";
                my $thickbox =
		    qq|<a href="$medium_image" title="<a href=$image_page>Go to image page </a>" class="thickbox" rel="gallery-images"><img src="$small_image" alt="" /></a> |;
                if ( $ind_count < 4 ) { $html .= qq|<td>$thickbox</td>|; }
                else                  { $more_html .= qq|<td>$thickbox</td>|; }
                $image_count--;
            }
            if ( $#{ $imageHoA{$individual_id} } > 4 ) {
                my $image_count = ( $#{ $imageHoA{$individual_id} } ) + 1;
                $html .= qq|<td>... (Total $image_count images)</td>|;
            }
            if   ( $ind_count < 4 ) { $html      .= "</tr>"; }
            else                    { $more_html .= "</tr>"; }
        }
        $html      .= "</table><br />";
        $more_html .= "</table><br />";
        if ( !$count ) {
            my $individual_name;
            my $no_image_count = 0;
            foreach my $individual_id (@no_image) {
                $no_image_count++;
                my $individual_obsolete_link =
		    get_individual_obsolete_link($locus, $individual_id, $user_type);
                if ( $no_image_count < 26 ) {
                    $individual_name = $individualHash{$individual_id};
                    $html .=
			qq|<a href="individual.pl?individual_id=$individual_id">$individual_name</a>&nbsp$individual_obsolete_link |;
                }
                else {
                    $more++;
                    $more_html .=
			qq|<a href="individual.pl?individual_id=$individual_id">$individual_name</a>&nbsp$individual_obsolete_link |;
                }
            }
        }
        else {
            foreach my $individual_id (@no_image) {
                $more++;
                my $individual_obsolete_link =
		    get_individual_obsolete_link($locus, $individual_id, $user_type);
                my $individual_name = $individualHash{$individual_id};
                $more_html .=
		    qq|<a href="individual.pl?individual_id=$individual_id">$individual_name</a>&nbsp$individual_obsolete_link |;
            }
        }
    }
    
    if ($more) {
        my ( $more_link, $contents ) = collapser(
            {
                linktext => "<b> See $more more accessions </b>",
		
                #hide_state_linktext => $title,
                content   => $more_html,
                collapsed => 1,
                id        => "more_individuals_display"
            }
	    );
        $html .= "$more_link\n$contents";
    }
    return ( $html, scalar(@individuals) );
}    #get_individuals_html

############################javascript code

sub associate_registry {
    my $locus         = shift;
    my $locus_id     = $locus->get_locus_id();
    my $sp_person_id = shift;

    my $associate = qq^
	
	<a href=javascript:Locus.toggleAssociateRegistry()>[Associate a registry name with this locus]</a><br>
	<div id='associateRegistryForm' style="display: none">
            <div id='registry_search'>
	        Registry Name:
	        <input type="text" 
		       style="width: 50%"
		       id="registry_input"
		       onkeyup="Locus.getRegistries(this.value)">
		<input type="button"
	               id="associate_registry_button"
		       value="associate registry"
		       disabled="true"
		       onclick="Locus.associateRegistry('$locus_id','$sp_person_id');this.disabled=false;">
		 
	        <select id="registry_select"
	                style="width: 100%"
			name="registry_select"
			size=10 
			onchange="Locus.updateRegistryInput()">
                   
		</select>
		     
	        Click <a href=javascript:Locus.addRegistryView()>here</a> to add a new registry name to our database
	    </div>
		     
	    <div id="registry_add" style="display: none">
	        <b>Please enter the values for the new registry name below (* is required)</b><br><br>
		<table cellspacing="0" cellpadding="0">
		    <tr><td>*Registry Symbol: </td><td width="20">&nbsp;</td>
		    <td><input type="text" id="registry_symbol" onblur="Locus.enableButton();" onchange="Locus.enableButton();"></td></tr>
		    <tr><td>*Registry Name: </td><td width="20">&nbsp;</td>
		    <td><input type="text" id="registry_name" onblur="Locus.enableButton();" onchange="Locus.enableButton();"></td></tr>
		</table>
		Registry Description:<br>
		<textarea id="registry_description" style="width: 100%"></textarea><br>
		<input type="button" disabled="true" id="add_registry_button" value="Add New Registry" onclick="Locus.addRegistry('$locus_id', '$sp_person_id');this.disabled=true;"><br>
		Click <a href=javascript:Locus.searchRegistries()>here</a> to go back to the registry search
            </div>
	</div>

	
^;

    return $associate;
}

sub associate_individual {
    
    my $locus         = shift;
    my $locus_id     = $locus->get_locus_id();
    my $sp_person_id = shift;

    my $associate_html = qq^

<div id="associateIndividualForm" style="display: none">
    Accession name:
    <input type="text"
           style="width: 50%"
           id="locus_name"
           onkeyup="Locus.getIndividuals(this.value, '$locus_id');">
    <input type="button"
           id="associate_individual_button"
           value="associate accession"
	   disabled="true"
           onclick="Locus.associateAllele('$sp_person_id');this.disabled=true;">
    <select id="individual_select"
            style="width: 100%"
	    onchange="Locus.getAlleles('$locus_id')"
            size=10>
       </select>

    <b>Would you Like to specify an allele?</b>
    <select id="allele_select"
            style="width: 100%">
    </select>

</div>
^;

    return $associate_html;
}


sub assign_owner {
    my $locus        = shift;
    my $locus_id    = $locus->get_locus_id();
    my $object_type = "locus";

    my $assign = qq^
	<a href=javascript:Tools.toggleAssignFormDisplay()>[Assign a locus owner]</a> Notice: 'user' account will be updated to 'submitter' <br>
	<div id='assignOwnerForm' style="display:none">
            <div id='user_search'>
	        First name or last name:
	        <input type="text" 
		       style="width: 50%"
		       id="user_input"
		       onkeyup="Tools.getUsers(this.value)">
		<input type="button"
	               id="associate_button"
		       value="assign owner"
                       disabled="true"
		       onclick="Tools.assignOwner('$locus_id', '$object_type');this.disabled=false;">
		 
	        <select id="user_select"
	                style="width: 100%"
			onchange= "Tools.enableButton('associate_button');"
	      	        size=5> 
                 </select>
		
           </div>
	   </div>
	   <BR>

^;
    return $assign;
}

sub associated_figures {

    my $locus         = shift;
    my $locus_id     = $locus->get_locus_id();
    my $sp_person_id = shift;

    my $associate_html = qq^
       <span>
       <a href="/image/add_image.pl?type_id=$locus_id&type=locus&action=new&refering_page=/phenome/locus_display.pl?locus_id=$locus_id"> 
       [Add notes, figures or images]</a></span>
^;

    return $associate_html;
}


sub get_individual_obsolete_link {
    my $locus                    = shift;
    my $individual_id            = shift;
    my $user_type = shift;
    my $individual_obsolete_link = "";
    my $individual_allele_id = $locus->get_individual_allele_id($individual_id);
    if (   ( $user_type eq 'submitter' )
	   || ( $user_type eq 'curator' )
	   || ( $user_type eq 'sequencer' ) )
    {
        $individual_obsolete_link = qq| 
	    <a href="javascript:Locus.obsoleteIndividualAllele('$individual_allele_id')">[Remove]</a>
	    
	    <div id='obsoleteIndividualAlleleForm' style="display: none">
            <div id='individual_allele_id_hidden'>
	    <input type="hidden" 
	    value=$individual_allele_id
	    id="$individual_allele_id">
	    </div>
	    </div>
	    |;
	
    }
    return $individual_obsolete_link;
}

sub merge_locus {
    my $locus        = shift;
    my $locus_id    = $locus->get_locus_id();
    my $object_type = "locus";
    my $common_name = $locus->get_common_name();
    my $merge       = qq^
	<a href=javascript:Tools.toggleMergeFormDisplay()>[Merge locus]</a> Warning: Merged locus will be set to obsolete! Unobsoleting is possible only directly via the database! <br>
	<div id='mergeLocusForm' style="display:none">

	<div id='locus_merge'>
	     <input type="hidden" 
	     value=$common_name
	     id ="common_name"
	     >
	     locus name
	        <input type="text" 
		       style="width: 50%"
		       id="locus_input"
		       onkeyup="Locus.getMergeLocus(this.value, $locus_id)">
		<input type="button"
	               id="merge_locus_button"
		       value="merge locus"
                       disabled="true"
		       onclick="Locus.mergeLocus('$locus_id');this.disabled=false;">
		 
	        <select id="locus_list"
	                style="width: 100%"
			onchange= "Locus.enableMergeButton();"
	      	        size=5> 
                 </select>
	      </div>
	   </div>
	   <BR>

^;
    return $merge;
}

#returns string html listing of locus sequence matches found in ITAG gbrowse DBs
sub genomic_annots_html {

    my $locus    = shift;
    my $locus_id = $locus->get_locus_id();


    # look up any gbrowse cross-refs for this locus id, if any
    my @xrefs = map {
        $_->xrefs({ -types      => ['match'],
                    -attributes => { sgn_locus_id => $locus_id },
                 }),
    } $c->enabled_feature('gbrowse2');

    return '<span class="ghosted">None</span>'
        unless @xrefs;


    # and now convert each of the matched regions into HTML strings
    # that display them
    return join "\n", map _render_genomic_xref( $_ ), @xrefs;
}

sub _render_genomic_xref {
    my ( $xref ) = @_;

    # look up all the matching locus sequence names
    my @locus_seqnames =
        distinct
        map {
            my $f = $_;
            my $p = parse_identifier(
                $f->target->seq_id,
                'sgn_locus_sequence'
               ) or die "cannot parse " . $f->target->seq_id;
            $p->{ext_id}
        }
        @{$xref->seqfeatures};

    my $linked_img = CGI->a( { href => $xref->url },
                              CGI->img({ #style => "border: 1px solid #ddd; border-top: 0; padding: 1em 0; margin:0",
                                         style => 'border: none',
                                         src   => $xref->preview_image_url })
                            );


    my $sequences_matched =
        @locus_seqnames > 1 ? 'Sequences matched'
                            : 'Sequence matched';

    return join('',
                 '<div style="border: 1px solid #777; padding-bottom: 10px">',
                 info_table_html(
                     'Annotation Set'     => $xref->data_source->description,
                     'Feature(s) matched' => join( ', ', map $_->display_name || $_->primary_id, @{$xref->seqfeatures} ),
                     'Reference Sequence' => $xref->seqfeatures->[0]->seq_id,
                     $sequences_matched   => join( ', ', @locus_seqnames ),
                     #__tableattrs         => qq|summary="" style="margin: 1em auto -1px auto"|,
                     __border             => 0,
                     __multicol           => 3,
                    ),
                 '<hr style="width: 95%" />',
                 $linked_img,
                 '</div>',
                );
}

