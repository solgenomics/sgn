use strict;
use warnings;
use CXGN::Page;


use CXGN::People;
use CXGN::Page::FormattingHelpers qw(
        info_section_html
        page_title_html
        columnar_table_html
        info_table_html
        html_optional_show
        html_alternate_show
        tooltipped_text
      );

use CXGN::Phenome::Locus;


use CXGN::Chado::CV;
use CXGN::Chado::Feature;


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

my ( $tgrc ) =
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


my $sequence_links;
if ($locus_name) {
    my $genbank;
    if ( !$genbank ) {
	$genbank = qq|<span class=\"ghosted\">none </span>|;
    }
    
    my $dyn_unigenes;
    
    $sequence_links = info_table_html(
	'SGN Unigenes'       => $dyn_unigenes,
	'GenBank Accessions' => $genbank,
        'Genome Matches'     => genomic_annots_html($locus),
        __border             => 0,
	);
}

my $seq_count;# = $gb_count + $unigene_count;
print info_section_html(
    title       => "Sequence annotations ($seq_count)",
    contents    => $sequence_links,
    id          => 'unigenes',
    collapsible => 1,
    collapsed   => 1,
    );


##########literature ########################################


my $ont_count = $locus->count_ontology_annotations();

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
    my ( $tgrc,$genbank );
    ##tgrc
    foreach ( @{ $dbs{'tgrc'} } ) {
        if ( $_->[1] eq '0' ) {
            my $url       = $_->[0]->get_urlprefix() . $_->[0]->get_url();
            my $accession = $_->[0]->get_accession();
            $tgrc .=
		qq|$locus_name is a <a href="$url$accession" target="blank">TGRC gene</a><br />|;
        }
    }
    
     
    return ( $tgrc );
}

########################
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

