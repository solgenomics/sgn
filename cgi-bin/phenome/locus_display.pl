use strict;
use warnings;
use CXGN::Page;


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


use CXGN::Chado::CV;
use CXGN::Chado::Feature;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;


use CXGN::Tools::Identifiers qw/parse_identifier/;
use CXGN::Tools::List qw/distinct/;

use CXGN::Phenome::Locus::LocusPage;
use HTML::Entities;

our $c;
my $d = CXGN::Debug->new();


#####################
use CGI qw / param /;
use CXGN::DB::Connection;
use CXGN::Login;

my $q = CGI->new();
my $dbh = CXGN::DB::Connection->new();
my $login = CXGN::Login->new($dbh);

my $person_id = $login->has_session();

my $user = CXGN::People::Person->new($dbh, $person_id);
my $user_type = $user->get_user_type();

my $locus_id = $q->param("locus_id") ;
my $action =  $q->param("action");

#print $c->render_mason("/locus/initialize.mas",
#            locus_id => $locus_id
#);

$c->forward_to_mason_view('/locus/index.mas',  action=> $action,  locus_id => $locus_id , user=>$user, dbh=>$dbh);




#############
my $time = time();


my $script = "/phenome/locus_display.pl?locus_id=$locus_id";

my $locus= CXGN::Phenome::Locus->new( $dbh, $locus_id  );

my $locus_name = $locus->get_locus_name();
my $organism   = $locus->get_common_name();

my @owners   = $locus->get_owners();


####################################################
#get all dbxref  annotations: pubmed, ncbi sequences, GO, PO, tgrc link
####################################################
my @allele_objs = $locus->get_alleles();    #array of allele objects

my ( $tgrc, $pubs, $pub_count, $genbank, $gb_count, $onto_ref ) =
    get_dbxref_info($locus, @allele_objs);

##############################
    #display locus details section
#############################

my $locus_html= qq| <table width="100%"><tr><td>|;


#########################
#####################################


if ($locus_name) {
    my $locus_html;
    $locus_html .= "<br />" . $tgrc;
    
}


#####################           UNIGENES AND SOLCYC

my @unigenes = $locus->get_unigenes();
my $unigene_count=0;
my $solcyc_count=0;
foreach (@unigenes) { 
    $unigene_count++ if $_->get_status eq 'C'; 
}

print $c->render_mason("/locus/solcyc.mas");

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
        $ontology_subtitle .= qq|<a href="javascript:Tools.toggleContent('associateOntologyForm', 'locus_ontology')">[Add ontology annotations]</a> |;
        $ontology_add_link = $c->render_mason("/locus/associate_ontology.mas",
            locus_id => $locus_id
        );
    }
}
else {
    $ontology_subtitle =
	qq |<span class = "ghosted"> [Add ontology annotations]</span> |;
}

my $dyn_ontology_info = $c->render_mason("/locus/ontology.mas");

print info_section_html(
    title       => "Ontology annotations ($ont_count)",
    subtitle    => $ontology_subtitle,
    contents    => $ontology_add_link . $dyn_ontology_info,
    id          => "locus_ontology",
    collapsible => 1,
    collapsed   => 1,
    );


#########################################################
#functions used in the locus page:
##

#######################

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
    my @sorted;
 
    @sorted = sort { $a->[0]->get_accession() <=> $b->[0]->get_accession() } @{ $dbs{PMID} } if  defined @{ $dbs{PMID} } ;
 
    foreach ( @sorted  ) {
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
	qq|<div><a href="/chado/publication.pl?pub_id=$pub_id" >$db:$accession</a> $pub_title ($year) $abstract_view </div><br /> |;
    return $pub_info;
}    #


#######################################################
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

