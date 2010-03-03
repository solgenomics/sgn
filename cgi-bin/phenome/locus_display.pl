#####################################################################
#
#  Displays a locus detail page.
#
######################################################################

#############NOTES BY TIM THE INTERN######################################
#
#Things that should be thought about/done with the ajax used on this page and others:
##
# - Generate the ajax request in JSON rather than just strings
# - Add errback functions to the ajax requests in case the request fails
# - Implement a better way to notify user of a database error (or other error)
#   generated from the server side scripts.
#   Either figure out how to generate an errback or create a JSON error response
#
#
##########################################################################

my $locus_detail_page = CXGN::Phenome::LocusDetailPage->new();

package CXGN::Phenome::LocusDetailPage;

use base qw/CXGN::Page::Form::SimpleFormPage  /;

use strict;

use CXGN::Page;

use CXGN::Apache::Error;
use CXGN::DB::Connection;
use CXGN::People::PageComment;
use CXGN::People;
use CXGN::Contact;
use CXGN::Page::FormattingHelpers qw/info_section_html
  page_title_html
  columnar_table_html
  info_table_html
  html_optional_show
  html_alternate_show
  tooltipped_text
  /;
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
use CXGN::Tools::Organism;

#use CXGN::Phenome::Locus2Locus; #deprecated . Replaced by LocusgroupMember and LocusGroup
use CXGN::Phenome::LocusgroupMember;
use CXGN::Phenome::LocusGroup;
use CXGN::Sunshine::Browser;
use CXGN::ITAG::Release;
use CXGN::Tools::Identifiers qw/parse_identifier/;
use CXGN::Tools::List qw/distinct/;
use CXGN::Feed;
use CXGN::Phenome::Locus::LocusPage;

use SGN::Image; 

sub new {
    my $class  = shift;
    my $schema = 'phenome';
    my $self   = $class->SUPER::new(@_);
    return $self;
}

sub define_object {
    my $self = shift;
    $self->get_dbh->add_search_path(qw /phenome sgn /);
    my %args      = $self->get_args();
    my $locus_id  = $args{locus_id};
    my $user_type = $self->get_user()->get_user_type();
    $self->set_object_id($locus_id);
    $self->set_object(
        CXGN::Phenome::Locus->new( $self->get_dbh, $self->get_object_id ) );
    if ( $self->get_object()->get_obsolete() eq 't' && $user_type ne 'curator' )
    {
        $self->get_page->message_page("Locus $locus_id is obsolete!");
    }
    unless ( ( $locus_id =~ m /^\d+$/ ) || $args{action} eq 'new' ) {
        $self->get_page->message_page(
            "No locus exists for identifier $locus_id");
    }
    $self->set_primary_key("locus_id");
    $self->set_owners( $self->get_object()->get_owners() );
}

sub display_page {
    my $self = shift;

    my $time = time();
    print STDERR "start time = $time ! \n";
    my $locus      = $self->get_object();
    my $locus_id   = $self->get_object_id();
    my $locus_name = $locus->get_locus_name();
    my $organism   = $locus->get_common_name();

    $self->get_page->jsan_use("CXGN.Phenome.Tools");
    $self->get_page->jsan_use("CXGN.Phenome.Locus");
    $self->get_page->jsan_use("MochiKit.DOM");
    $self->get_page->jsan_use("Prototype");
    $self->get_page->jsan_use("jQuery");
    $self->get_page->jsan_use("thickbox");
    $self->get_page->jsan_use("MochiKit.Async");
    $self->get_page->jsan_use("CXGN.Sunshine.NetworkBrowser");
    $self->get_page->jsan_use("CXGN.Phenome.Locus.LocusPage");
    #$self->get_page->jsan_use("CXGN.Page.Form.JSFormPage");

    #used to show certain elements to only the proper users
    my $login_user      = $self->get_user();
    my $login_user_id   = $login_user->get_sp_person_id() || "";
    my $login_user_type = $login_user->get_user_type() || "";
    my @object_owners   = $locus->get_owners();

    my %args   = $self->get_args();
    my $action = $args{action};

    if ( !$locus->get_locus_id() && $action ne 'new' && $action ne 'store' ) {
        $self->get_page->message_page("No locus exists for this identifier");
    }

    $self->get_page->header("SGN $organism locus: $locus_name");
    my $page = "/phenome/locus_display.pl?locus_id=$locus_id";
    print page_title_html("$organism \t'$locus_name'\n");

    print CXGN::Phenome::Locus::LocusPage::initialize($locus_id);

    ####
    #initialize the form (set objecName and objectId)
    #print CXGN::Phenome::Locus::LocusPage::init_locus_form($locus_id);
    #print the javascript form 
    #print CXGN::Phenome::Locus::LocusPage::include_locus_form();
    
    #####
    print STDERR "!!!Printing page title :  " . ( time() - $time ) . "\n";
####################################################
    #get all dbxref  annotations: pubmed, ncbi sequences, GO, PO, tgrc link
####################################################
    my @allele_objs = $locus->get_alleles();    #array of allele objects
    my ( $tgrc, $pubs, $pub_count, $genbank, $gb_count, $onto_ref ) =
      $self->get_dbxref_info(@allele_objs);

    print STDERR "!!!Got all dbxrefs! :  " . ( time() - $time ) . "\n";

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
    my $locus_html =
        qq| <table width="100%"><tr><td>|
      . $self->get_edit_links()
      . "<br />"
      . $self->get_form()->as_table_string();

#Only show if you are a curator or the object owner and there is no registry already assocaited with the locus
    if (
        (
            $login_user_type eq 'curator'
            || grep { /^$login_user_id$/ } @object_owners
        )
        && !( $locus->get_associated_registry() )
      )
    {
        if ($locus_name) { $locus_html .= $self->associate_registry(); }
        else {
            $curator_html .=
              qq |<span class = "ghosted"> [Associate registry name]</span> |;
        }
    }

    #merge locus form
    if ( $login_user_type eq 'curator' ) {
        $curator_html .= "<br />" . $self->merge_locus();
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
        $locus_html .= $self->print_locus_editor_info() . "<br>";

        #change ownership:
        if ( $login_user_type eq 'curator' ) {
            $curator_html .= $self->assign_owner();
        }
        my @owners  = $locus->get_owners();
        my $user_id = $self->get_user()->get_sp_person_id();
        if (   ( !( grep { $_ =~ /^$user_id$/ } @owners ) )
            && ( $login_user_type ne 'curator' ) )
        {

     #if ($locus->get_sp_person_id() != $self->get_user()->get_sp_person_id()) {
            $locus_html .=
qq|<a href="claim_locus_ownership.pl?locus_id=$locus_id&amp;action=confirm"> [Request editor privileges]</a><br /><br />|;
        }

        my $created_date = $self->get_object()->get_create_date();
        $created_date = substr $created_date, 0, 10;
        my $modified_date = $self->get_object()->get_modification_date() || "";
        $modified_date = substr $modified_date, 0, 10;

        my $updated_by = $locus->get_updated_by();
        my $updated =
          CXGN::People::Person->new( $self->get_dbh(), $updated_by );
        my $u_first_name = $updated->get_first_name();
        my $u_last_name  = $updated->get_last_name();
        $locus_html .= qq |Created on: $created_date |;
        if ($modified_date) {
            $locus_html .=
qq |  Last updated on: $modified_date  by  <a href="/solpeople/personal-info.pl?sp_person_id=$updated_by">$u_first_name $u_last_name</a><br />|;
        }

        #build a chromosome, map/s and marker/s objects
        $locus_html .= $self->get_location($locus);
    }

    my $name = $locus->get_associated_registry();
    if ($name) {
        $locus_html .= "This locus is associated with registry name: $name<br />";
    }

##############history ############

    if ( $login_user_type eq 'curator'
        || grep { /^$login_user_id$/ } @object_owners )
    {
        my $history_data = $self->print_locus_history($locus) || "";
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
    my $figure_html     = "";
    my $figure_subtitle = "";

    if (
        $locus_name
        && (   $login_user_type eq 'submitter'
            || $login_user_type eq 'curator'
            || $login_user_type eq 'sequencer' )
      )
    {
        $figure_subtitle .= $self->associated_figures();
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
        && (   $login_user_type eq 'curator'
            || $login_user_type eq 'submitter'
            || $login_user_type eq 'sequencer' )
      )
    {
        $ind_subtitle .=
qq| <a href="javascript:Tools.toggleContent('associateIndividualForm', 'locus_accessions')">[Associate accession]</a> |;
        $individuals_html = $self->associate_individual();
    }
    else {
        $ind_subtitle .=
          qq|<span class= "ghosted">[Associate accession]</span> |;
    }
    my ( $html, $ind_count ) = $self->get_individuals_html();
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
        && (   $login_user_type eq 'submitter'
            || $login_user_type eq 'curator'
            || $login_user_type eq 'sequencer' )
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
        my $allele_edit_link = $self->get_allele_edit_links($a);
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
               $login_user_type eq 'curator'
            || $login_user_type eq 'submitter'
            || $login_user_type eq 'sequencer'
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

    print STDERR "!!!Printing locus2locus :  " . ( time() - $time ) . "\n";

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
    print STDERR "!!!Got SolCyc links :  " . ( time() - $time ) . "\n";
    
    my $associate_unigene_form;
    if (
        (
	 $login_user_type eq 'curator'
	 || $login_user_type eq 'submitter'
	 || $login_user_type eq 'sequencer'
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
	    qq|<a href="/chado/add_feature.pl?type=locus&amp;type_id=$locus_id&amp;&amp;refering_page=$page&amp;action=new">[Associate new genbank sequence]</a><br />|;
	
	
	#printing associated unigenes section dynamically
	my $dyn_unigenes = CXGN::Phenome::Locus::LocusPage::include_locus_unigenes();
	print STDERR "!!!Got unigenes :  " . ( time() - $time ) . "\n";
	
	$sequence_links = info_table_html(
            'SGN Unigenes'       => $dyn_unigenes . $associate_unigene_form,
            'GenBank accessions' => $genbank,
            'Tomato genome'      => $self->itag_genomic_annots_html,
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
    print STDERR "!!!got sequence :  " . ( time() - $time ) . "\n";
    
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
        && (   $login_user_type eq 'curator'
            || $login_user_type eq 'submitter'
            || $login_user_type eq 'sequencer' )
      )
    {
        $pub_subtitle .=
qq|<a href="/chado/add_publication.pl?type=locus&amp;type_id=$locus_id&amp;refering_page=$page&amp;action=new"> [Associate publication] </a>|;
    }
    else {
        $pub_subtitle =
          qq|<span class=\"ghosted\">[Associate publication]</span>|;
    }

    my $disabled = "true";
    if ($login_user_id) { $disabled = "false"; }
    $pub_subtitle .=
qq | <a href="javascript:void(0)"onclick="window.open('locus_pub_rank.pl?locus_id=$locus_id','publication_list','width=600,height=400,status=1,location=1,scrollbars=1')">[Matching publications]</a> |;

    print STDERR "!!!Printing pub links :  " . ( time() - $time ) . "\n";

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
               $login_user_type eq 'curator'
            || $login_user_type eq 'submitter'
            || $login_user_type eq 'sequencer'
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

    print STDERR "!!!Printing ontology links! :  " . ( time() - $time ) . "\n";

####add page comments
    if ($locus_name) {
        my $page_comment_obj =
          CXGN::People::PageComment->new( $self->get_dbh(), "locus",
            $locus_id );
        print $page_comment_obj->get_html();
    }

    $self->get_page->footer();

}    #display_page

sub generate_form {
    my $self = shift;
    $self->init_form();

    my $locus = $self->get_object();
    my %args  = $self->get_args();

    my ( $organism_names_ref, $organism_ids_ref ) =
      CXGN::Tools::Organism::get_all_organisms( $self->get_dbh() );
    my ($lg_names_ref) =
      CXGN::Phenome::Locus::LinkageGroup::get_all_lgs( $self->get_dbh() );
    my ($lg_arms_ref) =
      CXGN::Phenome::Locus::LinkageGroup::get_lg_arms( $self->get_dbh() );

    if ( $self->get_action =~ /new|store/ ) {
        $self->get_form()->add_select(
            display_name       => "Organism ",
            field_name         => "common_name_id",
            contents           => $locus->get_common_name_id(),
            length             => 20,
            object             => $locus,
            getter             => "get_common_name_id",
            setter             => "set_common_name_id",
            select_list_ref    => $organism_names_ref,
            select_id_list_ref => $organism_ids_ref,
        );
    }
    if ( $locus->get_obsolete() eq 't' ) {
        $self->get_form()->add_label(
            display_name => "Status",
            field_name   => "obsolete_stat",
            contents     => 'OBSOLETE',
        );
    }
    $self->get_form()->add_field(
        display_name => "Locus name ",
        field_name   => "locus_name",
        object       => $locus,
        getter       => "get_locus_name",
        setter       => "set_locus_name",
        validate     => 'string',
    );

    $self->get_form()->add_field(
        display_name => "Symbol ",
        field_name   => "locus_symbol",
        object       => $locus,
        getter       => "get_locus_symbol",
        setter       => "set_locus_symbol",
        validate     => 'token',
	formatting   => '<i>*</i>',
    );

    $self->get_form()->add_field(
        display_name => "Gene activity ",
        field_name   => "gene_activity",
        object       => $locus,
        getter       => "get_gene_activity",
        setter       => "set_gene_activity",
        length       => '50',
    );

    $self->get_form()->add_textarea(
        display_name => "Description ",
        field_name   => "description",
        object       => $locus,
        getter       => "get_description",
        setter       => "set_description",
        columns      => 40,
        rows         => => 4,
    );

    $self->get_form()->add_select(
        display_name       => "Chromosome ",
        field_name         => "lg_name",
        contents           => $locus->get_linkage_group(),
        length             => 10,
        object             => $locus,
        getter             => "get_linkage_group",
        setter             => "set_linkage_group",
        select_list_ref    => $lg_names_ref,
        select_id_list_ref => $lg_names_ref,
    );

    $self->get_form()->add_select(
        display_name       => "Arm",
        field_name         => "lg_arm",
        contents           => $locus->get_lg_arm(),
        length             => 10,
        object             => $locus,
        getter             => "get_lg_arm",
        setter             => "set_lg_arm",
        select_list_ref    => $lg_arms_ref,
        select_id_list_ref => $lg_arms_ref,
    );

    $self->get_form()->add_hidden(
        field_name => "locus_id",
        contents   => $args{locus_id},
    );

    $self->get_form()->add_hidden(
        field_name => "action",
        contents   => "store",
    );

    $self->get_form()->add_hidden(
        field_name => "sp_person_id",
        contents   => $self->get_user()->get_sp_person_id(),
        object     => $locus,
        setter     => "set_sp_person_id",

    );
    $self->get_form()->add_hidden(
        field_name => "updated_by",
        contents   => $self->get_user()->get_sp_person_id(),
        object     => $locus,
        setter     => "set_updated_by",
    );

    if ( $self->get_action =~ /view|edit/ ) {
        $self->get_form->from_database();
        $self->get_form()->add_hidden(
            field_name => "common_name_id",
            contents   => $locus->get_common_name_id(),
        );

    }
    elsif ( $self->get_action =~ /store/ ) {
        $self->get_form->from_request( $self->get_args() );
    }

}

sub delete {
    my $self = shift;
    $self->check_modify_privileges();
    my $locus      = $self->get_object();
    my $locus_name = $locus->get_locus_name();
    $locus->delete();
    $self->send_locus_email('delete');
    $self->get_page()->message_page("The locus $locus_name has been deleted.");
}

sub delete_dialog {

    my $self = shift;
    $self->check_modify_privileges();
    my %args        = $self->get_args();
    my $title       = shift;
    my $object_name = shift;
    my $field_name  = shift;
    my $object_id   = shift;
    my $locus_id    = $args{locus_id};
    my $back_link =
        "<a href=\""
      . $self->get_script_name() . "?"
      . $self->get_primary_key() . "="
      . $object_id
      . "\">Go back to locus page without deleting</a>";

    $self->get_page()->header();

    page_title_html("$title");
    print qq { 	
	<form>
	Delete locus (id=$object_id)? 
	<input type="hidden" name="action" value="delete" />
	<input type="hidden" name="$field_name" value="$object_id" />
	<input type="submit" value="Delete" />
	</form>
	
	$back_link

    };

    $self->get_page()->footer();
}

# override store to check if a locus with the submitted symbol/name already exists in the database

sub store {
    my $self     = shift;
    my $locus    = $self->get_object();
    my $locus_id = $self->get_object_id();
    my %args     = $self->get_args();
    print STDERR "...overriding store in locus_display.pl....*********\n";
    $locus->set_common_name_id( $args{common_name_id} );
    my ($message) =
      $locus->exists_in_database( $args{locus_name}, $args{locus_symbol} );

    print STDERR "!!!!!!locus_display.pl store:  locus_id: $locus_id..."
      . $args{locus_name} . " \n";
    if ($message) {    #&& $name_id!= $locus_id && $name_obsolete==0 ) {
        $self->get_page()->header();

        print
qq| Locus $args{locus_name} (symbol=  $args{locus_symbol} ) already exists in the database <BR/>|;
        print
          qq { <a href="javascript:history.back(1)">back to locus page</a> };
        $self->get_page()->footer();
        print STDERR
          "locus_display.pl store: locus name or symbol exists in database!\n";
        exit();
    }
    else {
        print STDERR
"*_*_*_locus_display.pl store: calling store function in SimpleFormPage!\n";

        $self->send_locus_email();
        $self->SUPER::store(0);
    }
}

#########################################################
#functions used in the locus page:
##

sub empty_search {
    my ($page) = @_;

    #  $page->header();

    print <<EOF;

  <b>No locus was specified or this locus ID does not exist</b>

EOF

    # $page->footer();
    exit 0;
}

sub get_allele_edit_links {
    my $self     = shift;
    my $allele   = shift;
    my $locus    = $self->get_object();
    my $locus_id = $locus->get_locus_id();

    my $allele_edit_link = "";
    my $login_user_id    = $self->get_user()->get_sp_person_id();
    my $allele_id        = $allele->get_allele_id();
    if (   ( $allele->get_sp_person_id() == $login_user_id )
        || ( $self->get_user()->get_user_type() eq 'curator' ) )
    {
        $allele_edit_link =
qq | <a href="allele.pl?action=edit&amp;allele_id=$allele_id">[Edit]</a> |;
    }
    else { $allele_edit_link = qq | <span class="ghosted">[Edit]</span> |; }
}

sub get_location {
    my $self  = shift;
    my $locus = shift;

    my $lg_name = $locus->get_linkage_group();
    my $arm     = $locus->get_lg_arm();
    my $location_html;
    my @locus_marker_objs =
      $locus->get_locus_markers();    #array of locus_marker objects
    foreach my $lmo (@locus_marker_objs) {
        my $marker_id = $lmo->get_marker_id();    #{marker_id};
        my $marker =
          CXGN::Marker->new( $self->get_dbh(), $marker_id )
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
                          CXGN::Cview::MapFactory->new( $self->get_dbh() );
                        my $map = $map_factory->create(
                            { map_version_id => $map_version_id } );
                        my $map_version_id = $map->get_id();
                        my $map_name       = $map->get_short_name();

                        my $chromosome =
                          CXGN::Cview::ChrMarkerImage->new( "", 100, 150,
                            $self->get_dbh(), $lg_name, $map, $marker_name );
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
        my $map_factory = CXGN::Cview::MapFactory->new( $self->get_dbh() );

        my $map = $map_factory->create( { map_id => $map_id } );
        if ($map) {
            my $map_name = $map->get_short_name();
            my ( $north, $south, $center ) = $map->get_centromere($lg_name);

            my $dummy_name;
            $dummy_name = "$arm arm" if $arm;
            my $chr_image =
              CXGN::Cview::ChrMarkerImage->new( "", 150, 150, $self->get_dbh(),
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
    my $self  = shift;
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
          CXGN::People::Person->new( $self->get_dbh(), $updated_by_id );
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
    my $self       = shift;
    my $locus      = $self->get_object();
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
            $pubs .= $self->get_pub_info( $_->[0], 'PMID', $abs_count++ );
        }
    }
    foreach ( @{ $dbs{'SGN_ref'} } ) {
        $pubs .= $self->get_pub_info( $_->[0], 'SGN_ref', $abs_count++ )
          if $_->[1] eq '0';
    }

    my $gb_count = 0;
    foreach ( @{ $dbs{'DB:GenBank_GI'} } ) {
        if ( $_->[1] eq '0' ) {
            $gb_count++;
            my $url = $_->[0]->get_urlprefix() . $_->[0]->get_url();
            my $gb_accession =
              $self->CXGN::Chado::Feature::get_feature_name_by_gi(
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
    my $self          = shift;
    my $pub           = shift;
    my $abs_count     = shift;
    my $abstract      = $pub->get_abstract();
    my $authors       = $pub->get_authors_as_string();
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
    my $self = shift;
    my ( $dbxref, $db, $count ) = @_;
    my $pub_info;
    my $accession = $dbxref->get_accession();
    my $pub_title = $dbxref->get_publication()->get_title();
    my $year= $dbxref->get_publication()->get_pyear();
    my $pub_id    = $dbxref->get_publication()->get_pub_id();
    my $abstract_view =
      $self->abstract_view( $dbxref->get_publication(), $count );
    $pub_info =
qq|<div><a href="/chado/publication.pl?pub_id=$pub_id" >$db:$accession</a> $pub_title ($year). $abstract_view </div> |;
    return $pub_info;
}    #

sub print_locus_editor_info {
    my $self   = shift;
    my $html   = "Locus editors: ";
    my @owners = $self->get_object()->get_owners();
    foreach my $id (@owners) {
        my $person = CXGN::People::Person->new( $self->get_dbh(), $id );

        my $first_name = $person->get_first_name();
        my $last_name  = $person->get_last_name();

        $html .=
qq |<a href="/solpeople/personal-info.pl?sp_person_id=$id">$first_name $last_name</a>;|;
    }
    chop $html;
    return $html;
}

sub get_individuals_html {
    my $self        = shift;
    my @individuals = $self->get_object()->get_individuals();

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
              $self->get_individual_obsolete_link($individual_id);
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
                my $image = SGN::Image->new($self->get_dbh(), $image_id);
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
		    $self->get_individual_obsolete_link($individual_id);
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
		    $self->get_individual_obsolete_link($individual_id);
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

sub send_locus_email {
    my $self   = shift;
    my $action = shift;
    
    my $locus_id = $self->get_object()->get_locus_id();
    my $name     = $self->get_object()->get_locus_name();
    my $symbol   = $self->get_object()->get_locus_symbol();

    my $subject = "[New locus details stored] locus $locus_id";
    my $username =
        $self->get_user()->get_first_name() . " "
      . $self->get_user()->get_last_name();
    my $sp_person_id = $self->get_user()->get_sp_person_id();

    my $locus_link =
qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id|;
    my $user_link =
qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;

    my $usermail = $self->get_user()->get_private_email();
    my $fdbk_body;
    if ( $action eq 'delete' ) {
        $fdbk_body =
"$username ($user_link) has obsoleted locus  $name ($locus_link) \n  $usermail";
    }
    elsif ( $locus_id == 0 ) {
        $fdbk_body =
"$username ($user_link) has submitted a new locus  \n$name ($locus_link)\nLocus symbol: $symbol\n $usermail ";
    }
    else {
        $fdbk_body =
"$username ($user_link) has submitted data for locus $name ($locus_link) \nLocus symbol: $symbol\n $usermail";
    }

    CXGN::Contact::send_email( $subject, $fdbk_body,
        'sgn-db-curation@sgn.cornell.edu' );
    CXGN::Feed::update_feed( $subject, $fdbk_body );
}

############################javascript code

sub associate_registry {
    my $self         = shift;
    my $locus_id     = $self->get_object_id();
    my $sp_person_id = $self->get_user->get_sp_person_id();

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

    my $self         = shift;
    my $locus_id     = $self->get_object_id();
    my $sp_person_id = $self->get_user->get_sp_person_id();

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

#############MOVED TO LocusPage.pm!!!!!!!!!!!#############
###################################################################
##############sub associate_ontology_term{

###########################################################################
#########################locus2locus ###################
##MOVED TO LocusPage.pm see sub associate_locus_form####
########################################################


sub assign_owner {
    my $self        = shift;
    my $locus_id    = $self->get_object_id();
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

    my $self         = shift;
    my $locus_id     = $self->get_object_id();
    my $sp_person_id = $self->get_user->get_sp_person_id();

    my $associate_html = qq^
       <span>
       <a href="/image/add_image.pl?type_id=$locus_id&type=locus&action=new&refering_page=/phenome/locus_display.pl?locus_id=$locus_id"> 
       [Add notes, figures or images]</a></span>
^;

    return $associate_html;
}

sub get_unigene_obsolete_links {
    my $self                  = shift;
    my $locus                 = $self->get_object();
    my $unigene_id            = shift;
    my $unigene_obsolete_link = "";
    my $locus_unigene_id      = $locus->get_locus_unigene_id($unigene_id);
    if (   ( $self->get_user()->get_user_type() eq 'submitter' )
        || ( $self->get_user()->get_user_type() eq 'curator' )
        || ( $self->get_user()->get_user_type() eq 'sequencer' ) )
    {
        $unigene_obsolete_link = qq| 
	    <a href="javascript:Locus.obsoleteLocusUnigene('$locus_unigene_id')">[Remove]</a>
	    
	    <div id='obsoleteLocusUnigeneForm' style="display: none">
            <div id='locus_unigene_id_hidden'>
	    <input type="hidden" 
	    value=$locus_unigene_id
	    id="$locus_unigene_id">
	    </div>
	    </div>
	    |;

    }
    else {
        $unigene_obsolete_link = qq | <span class="ghosted">[Remove]</span> |;
    }
    return $unigene_obsolete_link;
}

sub get_individual_obsolete_link {
    my $self                     = shift;
    my $locus                    = $self->get_object();
    my $individual_id            = shift;
    my $individual_obsolete_link = "";
    my $individual_allele_id = $locus->get_individual_allele_id($individual_id);
    if (   ( $self->get_user()->get_user_type() eq 'submitter' )
        || ( $self->get_user()->get_user_type() eq 'curator' )
        || ( $self->get_user()->get_user_type() eq 'sequencer' ) )
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
    my $self        = shift;
    my $locus_id    = $self->get_object_id();
    my $object_type = "locus";
    my $common_name = $self->get_object()->get_common_name();
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
sub itag_genomic_annots_html {
    my ($self) = @_;

    my $locus    = $self->get_object;
    my $locus_id = $locus->get_locus_id;

    my @releases = CXGN::ITAG::Release->find
      or return '<span class="ghosted">temporarily unavailable</span>';

    my @matches = map _find_itag_matches($_,$locus_id), @releases;

    return join( "\n", @matches ) if @matches;
    return '<span class="ghosted">None</span>';
}
sub _find_itag_matches {
    my ($rel, $locus_id) = @_;

    return unless $rel->has_gbrowse_dbs;

    my $db = $rel->get_annotation_db('genomic')
        or die 'error, no genomic blast db, this point should not have been reached';

    # search for features in the blast db
    my @f = $db->features(
        -types      => ['match:ITAG_sgn_loci'],
        -attributes => { sgn_locus_id => $locus_id },
       );

    #group the features by contig regions
    my %regions;
    foreach my $f (@f) {
        my $region_key =
            join( ':', $f->sourceseq, $f->attributes('cdna_seq_name') );
        my $r = $regions{$region_key} ||= [];
        push @$r, $f;
    }

    # and now convert each of the matched regions into HTML strings
    # that display them
    return map _itag_features_to_html( $rel, $regions{$_} ),
           sort keys %regions;

}

sub _itag_features_to_html {
    my ($rel, $feats) = @_;

    # look up all the matching locus sequence names
    my @locus_seqnames = distinct map {
        my $f = $_;
        my $p =
            parse_identifier( $f->target->sourceseq,
                              'sgn_locus_sequence' )
                or die "cannot parse " . $f->target->sourcese;
        $p->{ext_id}
    } @$feats;

    my $gb_img_width     = 600;
    my $conf_name        = $rel->release_tag . '_genomic';
    my $ctg              = $feats->[0]->sourceseq;
    my ( $start, $end ) = ( $feats->[0]->start, $feats->[0]->end );
    ( $start, $end ) = ( $end, $start ) if $start > $end;
    my $gblink =
        "/gbrowse/gbrowse/$conf_name/?ref=$ctg&start=$start&end=$end";
    my $gbrowse_img =
        qq|<a href="$gblink"><img style="border: 1px solid #ddd; border-top: 0; padding: 1em 0; margin:0;" src="/gbrowse/gbrowse_img/$conf_name/?name=$ctg:$start..$end;type=genespan+mrna+sgn_loci+tilingpath;width=$gb_img_width;keystyle=between;grid=on" /></a>|;


    my $sequences_matched = @locus_seqnames > 1 ? 'Sequences matched' : 'Sequence matched';

    return qq|<div style="text-align: center">\n|
                  . info_table_html(
                      __multicol       => 3,
                      'Genome release' => $rel->release_name,
                      'Predicted cDNA matched' =>
                          $feats->[0]->attributes('cdna_seq_name'),
                      Contig               => $ctg,
                      $sequences_matched => join( ', ', @locus_seqnames ),
                      __tableattrs =>
                          qq|summary="" style="margin: 1em auto -1px auto; border-bottom: 0; width: ${gb_img_realwidth}px"|,
                     )
                  . $gbrowse_img
           .qq|</div>\n|
}



############# end of javascript functions

##
