
=head1 NAME

show_align.pl - a cgi-based graphical alignment viewer

=head1 DESCRIPTION

Generates an alignment view from data submitted through the input page (index.pl in this directory). It is a web script that supports the following cgi parameters:

=over 5

=item format

format may be either 'clustalw', 'fasta', or 'fasta_unaligned', and describes the format of the uploaded sequences. If format is 'fasta_unaligned', the sequences will be aligned using t_coffee.

=item seq_data

seq_data is the actual data uploaded, in the format described by the format parameter.

=item temp_file

if no seq_data is given, a temp_file name is supplied that specifies a previously parsed input. The temp_file specifies a file name, without the directory information, which will be in the default directory location, as defined in the conf object.

=item start_value

denotes the first position of the section of the alignment that should be displayed.

=item end_value

denotes the end position of the section of the alignment that should be displayed.

=item title

the title of the alignment, shown on the top of the page.

=item type

=over 5

=item 'nt' for nucleotide

=item 'pep' for peptide

=back 5

Not sure about this one. Defaults to peptide as default.

=item hide_seqs

a parameter that specifies a list of sequence ids, separated by whitespace, that should not be shown in the alignment. 

=item run

'local' means run on local host. 'cluster' means run job on cluster (if an alignment needs to be run).

=back

=head1 DEPENDENCIES

Depends on the CXGN code base, in particular heavily on CXGN::Alignment and others, and on GD for the graphics routines and File::Temp for the temp file handling.

=head1 AUTHOR(S)

Code by Chenwei Lin (cl295@cornell.edu). Documentation and minor modifications (ability to run T-coffee from the page) by Lukas Mueller (lam87@cornell.edu).

=cut

use strict;
use Storable qw /store/;
use File::Copy;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/ page_title_html blue_section_html  /;
use CXGN::Page::Widgets qw/ collapser /;
use File::Temp qw/tempfile/;
use File::Basename qw /basename/;
use CXGN::Phylo::Alignment;
use Bio::AlignIO;
use CXGN::DB::Connection;
use CXGN::Tools::Run;
use CXGN::Tools::Gene;
use CXGN::Tools::Identifiers qw/ identifier_namespace identifier_url /;
use CXGN::Tools::Entrez;
use HTML::Entities;
use CXGN::Tools::Param qw/ hash2param /;
use CatalystX::GlobalContext '$c';

our $ALIGN_SEQ_COUNT_LIMIT        = 500;
our $ALIGN_SEQ_TOTAL_LENGTH_LIMIT = 500_000;

my $page = CXGN::Page->new( "SGN Alignment Analyzer", "Chenwei-Carpita" );
$page->jsan_use("CXGN.Effects");

our (
    $format,    $seq_data,       $id_data,   $start_value,
    $end_value, $title,          $type,      $hide_seqs,
    $run,       $sv_similarity,  $sv_shared, $sv_indel,
    $show_sv,   $show_breakdown, $maxiters,  $force_gap_cds,
    $show_domains
  )
  = $page->get_arguments(
    "format",    "seq_data",       "id_data",   "start_value",
    "end_value", "title",          "type",      "hide_seqs",
    "run",       "sv_similarity",  "sv_shared", "sv_indel",
    "show_sv",   "show_breakdown", "maxiters",  "force_gap_cds",
    "show_domains"
  );

my ( $image_content, $sum_content, $seq_sum_content, $sv_content, $al_content,
    $combined_content );

our ( $temp_file, $cds_temp_file ) =
  $page->get_arguments( "temp_file", "cds_temp_file" );

our ( $family_nr, $i_value, $family_id ) =
  $page->get_arguments( "family_nr", "i_value", "family_id" );

if ( $family_id && !( $family_nr || $i_value ) ) {
    my $dbh = $c->dbc->dbh;
    my $sth =
      $dbh->prepare(
"SELECT family_nr, i_value FROM sgn.family LEFT JOIN sgn.family_build USING (family_build_id) WHERE family_id=?"
      );
    $sth->execute($family_id);
    ( $family_nr, $i_value ) = $sth->fetchrow_array();
}

$show_breakdown = 1    if $show_breakdown;
$show_sv        = 1    if $show_sv;
$maxiters       = 1000 if ( $maxiters > 1000 );
$maxiters ||= 2;

$show_domains = 1 unless ( $show_domains eq '0' );

#Run locally by default, cluster will run if the computation
#is found to be intensive (later in script)
unless ( $run =~ /^(local)|(cluster)$/ ) { $run = "local"; }

#############################################################
#Check if the input sequence is empty
unless ( $seq_data
    || $id_data
    || $temp_file
    || $family_id
    || ( $family_nr && $i_value ) )
{
    &input_err_page( $page, "No sequence data provided!\n" );
}

#############################################################
#If a $seq_data is passed to the page, write the content of $seq_data into a temp file

our $HTML_ROOT_PATH = $c->config->{'basepath'};
our $PATH     = $page->path_to( $page->tempfiles_subdir('align_viewer') );
unless( -d $PATH ) {
    mkdir $PATH
        or die "temp dir '$PATH' does not exist, and could not create";
}
our $tmp_fh;
our $CLUSTER_SHARED_TEMPDIR = $c->config->{'cluster_shared_tempdir'};
our $NOCLUSTER              = $c->config->{'nocluster'};

#You can send the temp_file as a filename and not a full path, good for security
unless ( $temp_file =~ /\// ) {
    $temp_file = $PATH . "/" . $temp_file;
}
unless ( $cds_temp_file =~ /\// ) {
    $cds_temp_file = $PATH . "/" . $cds_temp_file;

    #If a temp file is set, we are definitely CDS
    #Fixes imagemap problem:
    $type = "cds" if ( -f $cds_temp_file );
}

if ( -f $cds_temp_file && $force_gap_cds ) {

    #The CDS temp file needs to be gapped
    $cds_temp_file = build_gapped_cds_file( $temp_file, $cds_temp_file );
}

# upload file, if requested... (Lukas, 2006/09/05)
#
my $upload = $page->get_upload("upload");
my $upload_fh;

# print STDERR "Uploading file $args{upload_file}...\n";
if ( defined $upload ) {
    $upload_fh = $upload->fh();
    while (<$upload_fh>) {
        $seq_data .= $_;
    }
}

my @good_ids = ();
if ( $seq_data =~ /\S+/ ) {
    $tmp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0,
    );

    $temp_file = $tmp_fh->filename;
    print $tmp_fh "$seq_data";

    close $tmp_fh;

    # Convert the input file into fasta if it is clustal
    if ( $format eq 'clustalw' ) {
        my $temp_file_fasta = $temp_file . ".fasta";
        convert_clustal_fasta( $temp_file, $temp_file_fasta );

        # continue with the converted file...
        $temp_file = $temp_file_fasta;
    }
}
elsif ( $id_data =~ /\S+/ ) {
    unless ( -f $temp_file ) {
        my $tmp_fh = File::Temp->new(
            DIR    => $PATH,
            UNLINK => 0,
        );
        $temp_file = $tmp_fh->filename;
        $tmp_fh->close();
    }
    $format = "fasta_unaligned";

    open( my $temp_fh, '>', $temp_file ) or die $!;

    my @ids = split /\s+/, $id_data;
    foreach my $id (@ids) {
        if ( $id =~ /^gi:\d+$/i
            || CXGN::Tools::Identifiers::is_genbank_accession($id) )
        {
            ($id) = $id =~ /^gi:(\d+)$/i if $id =~ /^gi:\d+$/;
            my $database = "protein";
            $database = "nucleotide" if $type ne "pep";
            my $entrez = CXGN::Tools::Entrez->new( { db => $database } );
            my $seq = $entrez->get_sequence($id);
            $id = "gi:$id" if $id =~ /^\d+$/;
            print $temp_fh ">$id\n$seq" if $seq;
            push( @good_ids, $id ) if $seq;
        }
        else {
            eval {
                my $gene    = CXGN::Tools::Gene->new($id, $c->dbc->dbh );
                my $seqtype = "";
                $seqtype = "protein" if $type eq "pep";
                $seqtype = "cds"     if $type eq "cds";
                $seqtype = "genomic" if $type eq "nt";
                my $seq = $gene->getSequence($seqtype);
                print $temp_fh ">$id\n$seq\n" if $seq;
            };
            if( my $err = $@ ) {
                $err =~ s/\n\s*Catalyst::.+//;
                warn $err;
            } else {
                push @good_ids, $id;

            }
        }
    }
    $id_data = join " ", @good_ids;
    close($temp_fh);
}
elsif ( $family_nr && $i_value ) {
    my $family_basedir = "/data/prod/public/family/$i_value";
    unless ( -d $family_basedir ) {
        &input_err_page( $page,
            "No current family build corresponds to an i_value of $i_value" );
    }
    unless ( -f "$family_basedir/pep_align/$family_nr.pep.aligned.fasta" ) {
        &input_err_page( $page,
            "Alignment was not calculated for this family" );
    }

    unless ( -f $temp_file ) {
        my $tmp_fh = File::Temp->new(
            DIR    => $PATH,
            UNLINK => 0,
        );
        $temp_file = $tmp_fh->filename;
        $tmp_fh->close();
    }
    $format = "fasta_aligned";
    $type   = "cds";

    #disable cds until kinks worked out
    if ( 0 && -f "$family_basedir/cds_align/$family_nr.cds.align.fasta" ) {
        $type = "cds";
        system
          "cp $family_basedir/cds_align/$family_nr.cds.align.fasta $temp_file";
    }
    else {
        $type = "pep";
        system
"cp $family_basedir/pep_align/$family_nr.pep.aligned.fasta $temp_file";
    }
}

#Check that the input file is a good FASTA, throw error page otherwise
our ( $SEQ_COUNT, $MAX_LENGTH, $TOTAL_LENGTH ) = fasta_check( $temp_file, $page );

#Also, use seq_count, maxiters, and max_length parameters for Muscle to see if we
#should run it on the cluster, otherwise allow running on the web server
if (   !$NOCLUSTER && ( $maxiters * $SEQ_COUNT * $MAX_LENGTH > 30000 )
    || !$maxiters )
{
    $run = "cluster";
}
##Convert cds to protein, but if cds_temp_file exists,
#the conversion was already done on the previous page (or before)
if ( $type eq "cds" && $temp_file && !( -f $cds_temp_file ) ) {
    my $new_temp_fh = File::Temp->new(
        DIR    => $PATH,
        UNLINK => 0,
    );
    my $new_temp = $new_temp_fh->filename;
    my $instream = Bio::SeqIO->new( -file => $temp_file, -format => 'fasta' );
    while ( my $in = $instream->next_seq() ) {
        my $seq = $in->seq();
        my $id  = $in->id();
        my $len = length $seq;
        my $member;
        eval {
            $member = CXGN::Phylo::Alignment::Member->new(
                id          => $id,
                seq         => $seq,
                type        => "cds",
                start_value => 1,
                end_value   => $len
            );
            $member->translate_cds();
        };
        if ($@) {
            input_err_page( $page, $@ );
        }

        my $prot_seq = $member->{translated_protein_seq};
        print $new_temp_fh ">$id\n$prot_seq\n";
    }
    close($new_temp_fh);

    #Important transition happens here.  The temp_file
    #is now the translated protein sequence.  Maybe it's
    #gapped, maybe not, depends on the format parameter
    #and if the CDS was gapped
    $cds_temp_file = $temp_file;
    $temp_file     = $new_temp;
}

#############################################################
#Read the alignment sequence and store them in an align object

#First parse $hide_seqs
my %hidden_seqs = ();
my @ids = split /\s+/, $hide_seqs;
foreach (@ids) {
    $hidden_seqs{$_} = 1;
}

# align sequences if they are in the unaligned fasta format
# (added by Lukas, 9/5/2006)
if ( $format eq "fasta_unaligned" ) {

    if ( $SEQ_COUNT > $ALIGN_SEQ_COUNT_LIMIT ) {
        my $message =
"<center><span style='font-size:1.2em;'>You submitted <b>$SEQ_COUNT</b> sequences. Due to limited computational resources, we only <br>allow <b>$ALIGN_SEQ_COUNT_LIMIT or fewer</b> sequences to be aligned through our web interface.</span>";
        $message .=
"<br /><br /><span style='font-size:1.1em'>You can download and run your own copy of the <br />alignment software at <a href='http://www.drive5.com/muscle/'>www.drive5.com/muscle/</a></span></center>";
        input_err_page( $page, $message );
    }
    elsif( $TOTAL_LENGTH > $ALIGN_SEQ_TOTAL_LENGTH_LIMIT ) {
        input_err_page( $page, <<"" );
<center><span style='font-size:1.2em;'>You submitted <b>$TOTAL_LENGTH</b> bases of sequence. Due to limited computational resources, we only <br>allow <b>$ALIGN_SEQ_TOTAL_LENGTH_LIMIT or fewer</b> sequences to be aligned through our web interface.</span>
<br /><br /><span style='font-size:1.1em'>You can download and run your own copy of the <br />alignment software at <a href='http://www.drive5.com/muscle/'>www.drive5.com/muscle/</a></span></center>

    }

    run_muscle( $page, $run );
}

#die "\n$temp_file\n$cds_temp_file";

#Let's see the toolbar while we're just building the image

#######################################
## Construct Alignment ################
#######################################

my $disp_type = $type;
$disp_type = "pep" if ( $disp_type eq "cds" );

my $alignment = CXGN::Phylo::Alignment->new(
    name   => $title,
    width  => 800,
    height => 2000,
    type   => $disp_type
);
$alignment->{page} = $page;
my $instream;
my $len;

$sv_similarity = 95 unless ($sv_similarity);
$sv_indel      = 4  unless ($sv_indel);
$sv_shared     = 20 unless ($sv_shared);

$alignment->set_sv_criteria( $sv_shared, $sv_similarity, $sv_indel );

#die $temp_file;
$instream = Bio::SeqIO->new( -file => $temp_file, -format => 'fasta' );
while ( my $in = $instream->next_seq() ) {
    my $seq = $in->seq();
    my ( $id, $species ) = $in->id() =~ m/(.+)\/(.+)/;
    $id = $in->id();
    ( !$species ) and $species = ();

    my $hidden = 0;
    $hidden = 1
      if ( exists $hidden_seqs{$id} )
      ;    #skip the sequence if it is in the hide_seq

    chomp $seq;
    $len = length $seq;
    my $member;
    eval {

        $member = CXGN::Phylo::Alignment::Member->new(
            start_value => 1,
            end_value   => $len,
            id          => $id,
            seq         => $seq,
            hidden      => $hidden,
            species     => $species,
            type        => $disp_type
        );
        $alignment->add_member($member);
    };
    $@ and input_err_page( $page, $@ );

    my ( $gene, $annot, $sigpos, $cleavage );
    eval {
        $gene  = CXGN::Tools::Gene->new($id);
        $annot = $gene->getAnnotation;
        $annot = HTML::Entities::encode($annot);
    };
    unless ($@) {
        $member->set_tooltip($annot);
    }

    $member->show_remove();    #draw X for removal
    $member->show_link();
}

#Set the start value and end value#######
( !$start_value ) and $start_value = 1;
$alignment->set_start_value($start_value);
( !$end_value )       and $end_value = $len;
( $len < $end_value ) and $end_value = $len;
$alignment->set_end_value($end_value);

## Domain Highlighting ########################
$alignment->highlight_domains() if $show_domains;

### If cds_temp exists, create a $cds_alignment object, for producing CDS files

our $cds_alignment;
if ( -f $cds_temp_file && $type eq "cds" ) {
    $cds_alignment = CXGN::Phylo::Alignment->new(
        name => $title,
        type => "cds"
    );
    my $instream =
      Bio::SeqIO->new( -file => $cds_temp_file, -format => 'fasta' );
    while ( my $in = $instream->next_seq() ) {
        my $seq = $in->seq();
        my ( $id, $species ) = $in->id() =~ m/(.+)\/(.+)/;
        $id = $in->id();
        ( !$species ) and $species = ();

        my $hidden = 0;
        $hidden = 1
          if ( exists $hidden_seqs{$id} )
          ;    #skip the sequence if it is in the hide_seq

        chomp $seq;
        my $len = length $seq;
        my $member;
        eval {
            $member = CXGN::Phylo::Alignment::Member->new(
                start_value => 1,
                end_value   => $len,
                id          => $id,
                seq         => $seq,
                hidden      => $hidden,
                species     => $species,
                type        => $disp_type
            );
            $cds_alignment->add_member($member);
        };
        $@ and input_err_page( $page, $@ );
        $member->show_remove();    #draw X for removal
        $member->show_link();
    }
    $cds_alignment->set_start_value( $start_value * 3 - 2 );
    $cds_alignment->set_end_value( $end_value * 3 );
}

### Do page header AFTER all eval{} statements
$page->header;

############################################################
#Draw alignment image, unless we are at the original parameters and we
#have already drawn the most computationally intensive image

my $tmp_image = File::Temp->new(
    DIR    => $PATH,
    SUFFIX => '.png',
    UNLINK => 0,
);

#Render image
$alignment->render_png_file( $tmp_image, 'c' );
close $tmp_image;
$tmp_image =~ s/$HTML_ROOT_PATH//;

#Important for Ruler Image-Map Generation:
our ($temp_file_name)     = $temp_file     =~ /([^\/]+)$/;
our ($cds_temp_file_name) = $cds_temp_file =~ /([^\/]+)$/;

#Parameter hash for imagemap and other links on the page
our %PARAM = (
    format         => $format,
    start_value    => $start_value,
    end_value      => $end_value,
    title          => $title,
    type           => $type,
    hide_seqs      => $hide_seqs,
    sv_similarity  => $sv_similarity,
    sv_shared      => $sv_shared,
    sv_indel       => $sv_indel,
    show_sv        => $show_sv,
    show_breakdown => $show_breakdown,
    maxiters       => $maxiters,
    force_gap_cds  => $force_gap_cds,
    temp_file      => $temp_file_name,
    cds_temp_file  => $cds_temp_file_name,
    show_domains   => $show_domains
);

$alignment->set_fasta_temp_file($temp_file_name);
$alignment->set_cds_temp_file($cds_temp_file_name);
$alignment->set_param( \%PARAM );

$image_content = "<tr><td align=\"center\">";

$image_content .=
"<img border=0 src='$tmp_image' alt='Alignment Image' usemap='#align_image_map'/>";
$image_content .= $alignment->get_image_map( $show_sv, $show_breakdown );
$image_content .=
  "<div style=\"width:100%;text-align:left;padding-left:40px;\">";
if ($show_domains) {
    $image_content .=
        "<a href=\"show_align.pl?"
      . hash2param( \%PARAM, { show_domains => 0 } )
      . "\">Hide Domain Information</a>";
}
else {
    $image_content .=
        "<a href=\"show_align.pl?"
      . hash2param( \%PARAM, { show_domains => 1 } )
      . "\">Show Domain Information</a>";
}
$image_content .= "</div>";

if ( $start_value == 1 && $end_value == $len ) {
    $image_content .=
"<b>Click on a region of the image to zoom in.</b><br />You must submit the form below to change alignment parameters or remove members from analysis.";
}
else {
    $image_content .= "<a href='show_align.pl?";
    $image_content .=
      hash2param( \%PARAM, { start_value => 1, end_value => "" } );
    $image_content .= "'>&lt;&lt; See Whole Alignment &gt;&gt;</a>";
}

$image_content .= "</td></tr>";

my $term_help_content = <<HTML;
<table width="100%" summary="" cellpadding="3" cellspacing="3" border="0"><tr><td><p style='font-size:1.1em'>SGN Alignment Viewer analyzes and provides useful information that can be used to optimize the overlapping region of the alignment.</p></td></tr></table>
<table width="100%" summary="" cellpadding="3" cellspacing="0" border="0">
<tr style='background-color:#ddf'><th valign='top'>Coverage&nbsp;Range</th>
<td>The distance between the first and last element of the un-gapped sequence in the current alignment.</td></tr>
<tr><th valign='top'>Bases</th><td>Number of "real sequence characters" (non gap) in the sequence.</td></tr>
<tr style='background-color:#ddf'><th valign='top'>Gaps</th><td>Number of gaps in the aligment</td></tr>
<tr><th valign='top'>Medium</th><td>The middle position of all non-gap characters of the alignment sequence</td></tr>
<tr style='background-color:#ddf'><th valign='top'>Putative Splice Variant Pairs</th><td>Sequence pairs that are from the same species, that, by default <ol>
<li>Share at least 60 bases if they are nucleotides or 20 bases if they are peptides.
<li>Share at least 95% sequence similarity in the overlapping region. 
<li>Have insertion/deletion of at least 4 amino acids or 12 nucleotides in their common region.</ol> </td></tr>
<tr><th valign='top'>Putative Alleles</th><td>Sequence pairs that are from the same species, that, by default
<ol>
<li>Share at least 60 bases if they are nucleotides or 20 bases if they are peptides.  
<li>Share at least 95% sequence similarity in the overlapping region. 
<li>Have insertion/deletion of <b>not more than </b> 4 amino acids or 12 nucleotides in their common region.
</ol>
</td></tr>
<tr style='background-color:#ddf'><th valign='top'>Overlap Score</th><td>An indication of how well the sequence overlaps with other members in the alignment.  If a non-gap character of a sequence overlaps with a character in another alignment sequence, it gets a point.<br><br>Sometimes a few sequences share very little overlap with the rest, significantly reducing the overall overlapping sequence of the alignment.  Usually these sequences are short and will not help with the understanding of overall alignment.  We suggest the user leaves out these sequences before further analysis of the aligment sequence. </td></tr></table>
HTML
$term_help_content =
  blue_section_html( "<em>Help With Terms</em>", $term_help_content );

my ( $help_link, $hidden_help_content ) = collapser(
    {
        id                  => "alignment_help_content",
        alt_href            => "/about/align_term.pl",
        alt_target          => "align_about",
        linktext            => "(-) Help me understand terms on this page",
        hide_state_linktext => "(?) Help me understand terms on this page",
        linkstyle           => "font-size:1.1em",
        collapsed           => 1,
        content             => $term_help_content,
    }
);

##########################################################
#Write sequence output to temp files and create links to them

###########################################################
#Get summary information

$combined_content = get_combined_content($alignment);

############################################################
#Page printout: Nav Section

print
"<a href=\"index.pl?id_data=$id_data\" style=\"margin-left:10px;font-size:1.1em\">&lt;&lt; Start over</a>";
my $disp_title = "";
$disp_title = "View and Analyze Alignment of <em>$title</em>" if ($title);
$disp_title ||= "View and Analyze Alignment";
print page_title_html("$disp_title");

print "&nbsp;&nbsp;" . $help_link . "<br><br>";
print $hidden_help_content; #this is actually a blue_section_html, but the whole thing is hidden

my $image_title = "Alignment Image";
$image_title .= ":&nbsp;&nbsp; CDS Translated" if ( $type eq "cds" );
print blue_section_html( $image_title,
        '<table width="100%" cellpadding="0" cellspacing="0" border="0">'
      . $image_content
      . '</table>' );

print blue_section_html(
    'Summary, Files, Change Parameters',
    '<table width="100%" cellpadding="5" cellspacing="0" border="0">'
      . $combined_content
      . '</table>'
);

if ($show_breakdown) {
    $seq_sum_content = get_seq_sum_content($alignment);
}
else {
    $seq_sum_content .= "Not Calculated &nbsp;&nbsp;( <a href=\"show_align.pl?";
    $seq_sum_content .= hash2param( \%PARAM, { show_breakdown => 1 } );
    $seq_sum_content .=
      "\">showing this table</a> will increase page load time )";
}

###########################################################
#Find splice variants

if ($show_sv) {
    ( $sv_content, $al_content ) = get_sv_al_content($alignment);
}
else {
    $al_content = "Not Calculated &nbsp;&nbsp;( <a href=\"show_align.pl?";
    $al_content .= hash2param( \%PARAM, { show_sv => 1 } );
    $al_content .= "\">showing this table</a> will increase page load time )";
    $sv_content = "Not Calculated &nbsp;&nbsp;( <a href=\"show_align.pl?";
    $sv_content .= hash2param( \%PARAM, { show_sv => 1 } );
    $sv_content .= "\">showing this table</a> will increase page load time )";
}

###########################################################
##Page Printout: Breakdown and Alleles
print blue_section_html( 'Alignment Breakdown', $seq_sum_content );

print blue_section_html( 'Putative Splice Variants', $sv_content );

print blue_section_html( 'Putative Alleles', $al_content );

#print blue_section_html('Output Sequences','<table width="100%" cellpadding="5" cellspacing="0" border="0">'.$seq_output_content.'</table>');

$page->footer();

sub get_combined_content {
    my $alignment       = shift;
    my $align_member_nr = $alignment->get_member_nr();
    my $ol_nr           = $alignment->get_overlap_num();

    my $id_list_ref   = $alignment->get_nonhidden_member_ids;
    my $seq_ref       = $alignment->get_nopad_seqs();
    my $align_seq_ref = $alignment->get_seqs();
    my $ol_seq_ref    = $alignment->get_overlap_seqs();
    my $sp_ref        = $alignment->get_member_species();

    my ( $cds_ids_ref, $cds_seq_ref, $cds_align_seq_ref, $cds_ol_seq_ref ) =
      ( undef, undef, undef, undef );
    if ($cds_alignment) {
        $cds_seq_ref       = $cds_alignment->get_nopad_seqs();
        $cds_align_seq_ref = $cds_alignment->get_seqs();
        $cds_ol_seq_ref    = $cds_alignment->get_overlap_seqs();
    }

    my %sp = %$sp_ref;

    my $file_links     = "";
    my $cds_file_links = "";
    my $tmp_seq_file;
    my ( $seq_file, $cds_file, $seq_align_file );
    ## Protein/Genomic Files:
    if ($seq_ref) {
        my $link;
        ( $seq_file, $link ) =
          build_seq_file( $id_list_ref, $seq_ref, "All Sequences (No Gaps)" );
        $file_links .= $link . "<br />";
    }
    else { $file_links .= "All Sequences (No Gaps)<br>" }

    if ($align_seq_ref) {
        my $link;
        ( $seq_align_file, $link ) =
          build_seq_file( $id_list_ref, $align_seq_ref,
            "All Alignment Sequences (Gapped)" );
        $file_links .= $link . "<br />";
    }
    else { $file_links .= "All Alignment Sequences (Gapped)<br/>"; }

    if ( $ol_nr > 0 ) {
        ($file_links) .=
          build_seq_file( $id_list_ref, $ol_seq_ref, "Overlap of Sequences" );
    }
    else { $file_links .= "Overlap of Sequences" }

    ## CDS Files, if the CDS alignment was made from cds_file:
    if ($cds_seq_ref) {
        my $link;
        ( $cds_file, $link ) =
          build_seq_file( $id_list_ref, $cds_seq_ref,
            "Coding Sequences (No Gaps)" );
        $cds_file_links .= $link . "<br />";
    }
    if ($cds_align_seq_ref) {
        $cds_file_links .=
          build_seq_file( $id_list_ref, $cds_align_seq_ref,
            "Coding Aligned Sequences (Gapped)" )
          . "<br />";
    }
    if ( $ol_nr > 0 && $cds_ol_seq_ref ) {
        $cds_file_links .=
          build_seq_file( $id_list_ref, $cds_ol_seq_ref,
            "Overlap of Coding Sequences" );
    }
    elsif ($cds_ol_seq_ref) { $cds_file_links .= "Overlap of Coding Sequences" }

    ############################################################
    # Summary, Files, And Alignment Parameter Changes

    my $combined_content = "<tr><td>";

    $combined_content .= "<table style='width:100\%;border-spacing:0px'><tr>";

    #Summary Content
    $combined_content .=
      "<td style='width:50%;vertical-align:middle;'><table width='100%'>";
    $combined_content .= "<tr><th>Type</th><td>";
    if ( $type eq 'nt' ) {
        $combined_content .= "Nucleotide</td></tr>";
    }
    else {
        $combined_content .= "Peptide</td></tr>";
    }
    $combined_content .=
      "<tr><th>No. Alignment Members</th><td>$align_member_nr</td></tr>";
    $combined_content .=
      "<tr><th>Selected Range</th><td>$start_value - $end_value</td></tr>";
    $combined_content .= "<tr><th>Overlap</th><td>$ol_nr";
    if ( $type eq 'nt' ) {
        $combined_content .= " bp</td></tr>";
    }
    else {
        $combined_content .= " aa</td></tr>";
    }

    if ($cds_file_links) {
        $combined_content .=
          "<tr><th>Protein Files:</th><td>$file_links</td></tr>";
        $combined_content .=
          "<tr><th>CDS Files:</th><td>$cds_file_links</td></tr>";
    }
    else {
        $combined_content .=
          "<tr><th>Sequence Files:</th><td>$file_links</td></tr>";
    }

    my $rerun_file;
    ($cds_file) ? ( $rerun_file = $cds_file ) : ( $rerun_file = $seq_file );
    my ($tmp_seq_name)       = $rerun_file     =~ /([^\/]+)$/;
    my ($tmp_seq_align_name) = $seq_align_file =~ /([^\/]+)$/;
    my $target = "_SGN_TREE_" . int( rand(10000000) );

    my $available_seq_count = 0;
    while ( my ( $id, $seq ) = each %$seq_ref ) {
        $available_seq_count++ if $seq =~ /\S/;
    }
    if ( $available_seq_count > 1 ) {
        $combined_content .= <<HTML;
	
	<tr><td colspan=2><br /> 
	<a href='index.pl?temp_file=$tmp_seq_name&maxiters=$maxiters&type=$type&format=fasta_unaligned&title=$title'>&gt;&gt; Re-run Alignment On Selected Range ($available_seq_count)</a>
	<br />This will allow you to specify greater accuracy by increasing the number of iterations performed by Muscle<br /><br />
	<a target="$target" href="/tools/tree_browser/index.pl?align_temp_file=$tmp_seq_align_name&align_type=pep&tree_from_align=1">
	&gt;&gt; Calculate Tree from Selected Range ($available_seq_count)</a><br />
	Use a quick neighbor-joining algorithm (Kimura) to calculate a tree based on the protein alignment, and analyze both in the combined alignment/tree browser.
	</td></tr>
HTML
    }
    else {
        $combined_content .= <<HTML;
	<tr><td colspan=2><br />
	Re-alignment and Tree Calculation cannot be performed, since there are less than two sequences for which data is available at this range
	</td></tr>
HTML
    }
    $combined_content .= "</table></td>";

    ### Modify and submit alignment parameters
    ##########################################

    $combined_content .=
      "<td><form method='post' action='show_align.pl' name='show_align'>";

    #hidden parameters
    $combined_content .= "<input type='hidden' name='title' value='$title' />";
    $combined_content .=
      "<input type='hidden' name='format' value='$format' />";
    $combined_content .=
      "<input type='hidden' name='temp_file' value='$temp_file' />";
    $combined_content .=
"<input type='hidden' name='cds_temp_file' value='$cds_temp_file_name' />";
    $combined_content .= "<input type='hidden' name='type' value='$type' />";

    #start and end value
    $combined_content .=
"<table style='border:0px;border-spacing:0px'><tr><th>Start Value</th><th>End Value</th></tr>";
    $combined_content .=
"<tr><td><input type='text' name='start_value' value='$start_value' /></td>";
    $combined_content .=
"<td><input type='text' name='end_value' value='$end_value' /></td></tr></table>";

    #Sequences to leave out
    $combined_content .=
      "<b>IDs of Sequences to Leave Out</b> (separated by spaces)<br>";
    $combined_content .=
"<textarea name='hide_seqs' id='hide_seqs' rows='2' cols='50'>$hide_seqs</textarea><br>";

    my $show_breakdown_checked = "";
    $show_breakdown_checked = "CHECKED" if ($show_breakdown);
    $combined_content .=
"<b><input type='checkbox' name='show_breakdown' $show_breakdown_checked> Calculate Coverage and Overlap Details</b> (Time Intensive)<br />";

    my $show_sv_checked = "";
    $show_sv_checked = "CHECKED" if ($show_sv);
    $combined_content .=
"<b><input type='checkbox' name='show_sv' $show_sv_checked> Calculate Splice Variants and Alleles</b> (Time Intensive)";
    $combined_content .= "<table style='border:0px;text-align:center'>";
    $combined_content .=
"<tr><th>% Similarity</th><th></th><th>Shared</th><th></th><th>InDel Limit</th></tr>";
    $combined_content .=
"<tr><td><input type='text' size=10 name='sv_similarity' value='$sv_similarity'></td><td width=3>&nbsp;</td>";
    $combined_content .=
"<td><input type='text' size=10 name='sv_shared' value='$sv_shared'></td><td width=3>&nbsp;</td>";
    $combined_content .=
"<td><input type='text' size=10 name='sv_indel' value='$sv_indel'></td></tr></table>";

    #submit
    $combined_content .=
      "<input type='submit' value='Change Alignment Details' /></form></td>";

    $combined_content .= "</tr></table>";
    $combined_content .= "</td></tr>";

    return $combined_content;
}

sub get_sv_al_content {
    my $alignment = shift;
    my ( $ob_ref, $pi_ref, $sv_sp_ref ) = $alignment->get_sv_candidates();
    my %ob    = %$ob_ref;
    my %pi    = %$pi_ref;
    my %sv_sp = %$sv_sp_ref;
    my ( $sv_content, $al_content ) = ( "", "" );
    if ( keys %ob ) {
        $sv_content =
          "<table width='100%' cellpadding='5' cellspacing='0' border='1'>";
        $sv_content .= "<tr>";
        $sv_content .= "<th>Species</th>";    # if $show_species;
        $sv_content .=
"<th>Sequence id</th><th>Sequence id</th><th>Overlap Bases</th><th>\% Similarity</th></tr>";
        foreach my $first_key ( keys %ob ) {
            foreach my $second_key ( keys %{ $ob{$first_key} } ) {
                $sv_content .= "<tr>";
                $sv_content .=
                  "<td>$sv_sp{$first_key}</td>";    # if $show_species;
                $sv_content .=
"<td>$first_key</td><td>$second_key</td><td>$ob{$first_key}{$second_key}</td><td>$pi{$first_key}{$second_key}</td></tr>";
            }
        }
        $sv_content .= "</table>";
        $sv_content .=
          "&nbsp;Reduce page load time by <a href=\"show_align.pl?";
        $sv_content .= hash2param( \%PARAM, { show_sv => 0 } );
        $sv_content .= "\">hiding this table</a>";

    }
    else {
        $sv_content =
          "None were found.  Reduce page load time by <a href=\"show_align.pl?";
        $sv_content .= hash2param( \%PARAM, { show_sv => 0 } );
        $sv_content .= "\">hiding this table</a>";

    }

    ###########################################################
    #Find alleles

    my ( $al_ob_ref, $al_pi_ref, $al_sp_ref ) =
      $alignment->get_allele_candidates();
    my %al_ob = %$al_ob_ref;
    my %al_pi = %$al_pi_ref;
    my %al_sp = %$al_sp_ref;

    if ( keys %al_ob ) {
        $al_content =
          "<table width='100%' cellpadding='5' cellspacing='0' border='1'>";
        $al_content .= "<tr>";
        $al_content .= "<th>Species</th>";    # if $show_species;
        $al_content .=
"<th>Sequence id</th><th>Sequence id</th><th>Overlap Bases</th><th>\% Similarity</th></tr>";
        foreach my $first_key ( keys %al_ob ) {
            foreach my $second_key ( keys %{ $al_ob{$first_key} } ) {
                $al_content .= "<tr>";
                $al_content .=
                  "<td>$al_sp{$first_key}</td>";    # if $show_species;
                $al_content .=
"<td>$first_key</td><td>$second_key</td><td>$al_ob{$first_key}{$second_key}</td><td>$al_pi{$first_key}{$second_key}</td></tr>";
            }
        }
        $al_content .= "</table>";
        $al_content .=
          "&nbsp;Reduce page load time by <a href=\"show_align.pl?";
        $al_content .= hash2param( \%PARAM, { show_sv => 0 } );
        $al_content .= "\">hiding this table</a>";
    }
    else {
        $al_content =
          "None were found.  Reduce page load time by <a href=\"show_align.pl?";
        $al_content .= hash2param( \%PARAM, { show_sv => 0 } );
        $al_content .= "\">hiding this table</a>";
    }
    return ( $sv_content, $al_content );
}

sub get_seq_sum_content {

    my $alignment = shift;
    ###########################################################
    #Analyze sequences and create analysis content
    my $member_ids_ref = $alignment->get_member_ids();
    my $ov_score_ref   = $alignment->get_all_overlap_score();
    my $medium_ref     = $alignment->get_all_medium();
    my ( $head_ref, $tail_ref ) = $alignment->get_all_range();
    my $ng_ref = $alignment->get_all_nogap_length();
    my $sp_ref = $alignment->get_member_species();

    my @member_ids = @$member_ids_ref;
    my %ov_score   = %$ov_score_ref;
    my %medium     = %$medium_ref;
    my %head       = %$head_ref;
    my %tail       = %$tail_ref;
    my %ng         = %$ng_ref;
    my %gap        = ();
    my %species    = %$sp_ref;

    foreach ( keys %ng ) {
        $gap{$_} = $tail{$_} - $head{$_} + 1 - $ng{$_};
    }
    my $show_species = 0;
    foreach ( keys %species ) {
        $show_species = 1 if $species{$_};
    }

    my $seq_sum_content = "";
    $seq_sum_content .=
      "<table width='100%' cellpadding='5' cellspacing='0' border='1'>";
    $seq_sum_content .= "<tr><th>Sequence ID</th>";
    $seq_sum_content .= "<th>Species</th>" if $show_species;
    $seq_sum_content .=
"<th>Coverage Range</th><th>Bases</th><th>Gaps</th><th>Medium</th><th>Overlap Score</th></tr>";

    foreach (@member_ids)
    { ##Access the align_seqs members this way, instead of by the keys of the hashes,  so that the sequences are grouped together
        $seq_sum_content .= "<tr><td>$_</td>";
        $seq_sum_content .= "<td>$species{$_}</td>" if $show_species;
        $seq_sum_content .=
"<td>$head{$_} - $tail{$_}</td><td>$ng{$_}</td><td>$gap{$_}</td><td>$medium{$_}</td><td>$ov_score{$_}</td></tr>";
    }
    $seq_sum_content .= "</table>";
    $seq_sum_content .=
      "&nbsp;Reduce page load time by <a href=\"show_align.pl?";
    $seq_sum_content .= hash2param( \%PARAM, { show_breakdown => 0 } );
    $seq_sum_content .= "\">hiding this table</a>";
    return $seq_sum_content;
}

sub build_gapped_cds_file {
    my $prot_file = shift;
    my $cds_file  = shift;
    my $instream  = Bio::SeqIO->new( -file => $prot_file, -format => 'fasta' );
    my $cds_instream =
      Bio::SeqIO->new( -file => $cds_file, -format => 'fasta' );

    my %cds_seq;
    my %prot_seq;

    while ( my $in = $instream->next_seq ) {
        my $id = $in->id();
        $prot_seq{$id} = $in->seq();
    }
    while ( my $in = $cds_instream->next_seq ) {
        my $id = $in->id();
        $cds_seq{$id} = $in->seq();
    }
    my $temp_fh = File::Temp->new(
        DIR    => $PATH,
        SUFFIX => '.txt',
        UNLINK => 0,
    );
    my $new_cds_temp_file = $temp_fh->filename;
    my $i                 = 0;
    my $st                = time();
    while ( my ( $id, $prot_seq ) = each %prot_seq ) {
        $i++;
        my $cds = $cds_seq{$id};

        my $member = CXGN::Phylo::Alignment::Member->new(
            id          => $id,
            seq         => $cds,
            type        => "cds",
            cds_nocheck => 1
        );
        $member->cds_insert_gaps($prot_seq);
        my $newseq = $member->get_seq();
        print $temp_fh ">$id\n$newseq\n";
    }
    my $et   = time();
    my $rate = ( $et - $st ) / $i;

    #die $rate ." seconds/member\n";

    $temp_fh->close();
    return $new_cds_temp_file;
}

sub build_seq_file {
    my $id_list_ref = shift;
    my $seq_ref     = shift;
    my $linkname    = shift;
    my $temp_fh     = File::Temp->new(
        DIR    => $PATH,
        SUFFIX => '.txt',
        UNLINK => 0,
    );
    my $outstream = Bio::SeqIO->new( -fh => $temp_fh, -format => 'fasta' );
    foreach (@$id_list_ref) {
        my $seq = Bio::Seq->new( -seq => $seq_ref->{$_}, -id => $_ );
        $outstream->write_seq($seq) if $seq_ref->{$_} =~ /\w/;
    }
    my $tempname = $temp_fh->filename;
    close $temp_fh;
    $tempname =~ s/$HTML_ROOT_PATH//;
    return ( $tempname,
        "<a target=\"sgn_align_file\" href=\"$tempname\">$linkname</a>" );
}

sub input_err_page {
    my $input_err_page = shift;
    my $err_message    = shift;
    $input_err_page->header();
    my ($disp_err_message) = $err_message =~ /(.*) at \/usr\/local\//;
    $disp_err_message = $err_message unless $disp_err_message;
    print page_title_html("Combined Tree/Alignment Error");
    print "$disp_err_message<br><br><a href=\"index.pl\">Start over</a><br>";
    $input_err_page->footer();
    exit;
}

sub fasta_check {
    my ( $file, $page, $n ) = @_;
    my ($filename) = $file =~ /([^\/]+)$/;
    my $count        = 0;
    my $maxlen       = 0;
    my $total_length = 0;
    my $instream = Bio::SeqIO->new( -file => $file, -format => 'fasta' );
    my $entry = $instream->next_seq();
    unless ( $entry && $entry->id && $entry->seq ) {
        input_err_page( $page, "FASTA needs IDs and Sequences [$filename]" );
    }
    $count++;
    $maxlen = $entry->length;
    $total_length += $entry->length;

    $entry  = $instream->next_seq;
    unless ( $entry && $entry->id && $entry->seq ) {
        input_err_page( $page, "FASTA must have at least two valid sequences" );
    }
    $count++;
    $maxlen = $entry->length if $entry->length > $maxlen;
    $total_length += $entry->length;

    while ( $entry = $instream->next_seq() ) {
        unless ( $entry->id && $entry->seq ) {
            input_err_page( $page, "Every entry must have ID AND sequence" );
        }
        $maxlen = $entry->length if $entry->length > $maxlen;
        $total_length += $entry->length;
        $count++;
    }
    return ( $count, $maxlen, $total_length );
}

sub run_muscle {
    my ( $page, $run ) = @_;
    my @local_run_output = "";
    my $command_line     = "";
    my $old_temp_file    = $temp_file;
    if ( $run eq "local" ) {
        my $wd = `pwd`;
        chomp $wd;
        my $result_file = $temp_file;
	$result_file .= ".aligned.fasta" unless $result_file =~ /\.aligned\.fasta$/;
        chdir $PATH;

#Within a limit of less than 50 sequences, muscle should run within 3 seconds. Wawa-woo-a!
        $command_line =
          "muscle -in $temp_file -out $result_file -maxiters $maxiters";
        print STDERR "Running: $command_line\n";
        @local_run_output = `$command_line `;
        $temp_file        = $result_file;
        if ( -f $cds_temp_file ) {

            #The CDS temp file needs to be gapped
            $cds_temp_file =
              build_gapped_cds_file( $temp_file, $cds_temp_file );
        }
        chdir $wd;
    }

    ## RUN ON CLUSTER NODES ###################################################

    if ( $run eq "cluster" ) {

        my ( undef, $filename ) = tempfile(
            TEMPLATE => "jobXXXXXX",
            DIR      => $CLUSTER_SHARED_TEMPDIR
        );

        copy( $temp_file, $filename )
          || die "Cannot copy $temp_file to $filename";

        chdir $CLUSTER_SHARED_TEMPDIR;

        print STDERR "Running on cluster: $command_line\n";

        #CXGN::Tools::Run->temp_base($CLUSTER_SHARED_TEMPDIR);

        # generate a .req file that will indicate to the wait.pl script
        # that such a request has been made
        #
        system("touch $filename.req");

        my $old_wd = `pwd`;

        # my $job = CXGN::Tools::Run->run_cluster(
        #     "muscle",
        #     -in       => "$filename",
        #     -out      => "$filename.aln",
        #     -maxiters => $maxiters,
        #     { #if the next line is uncommented, we get the weird STDERR problem I was talking about --ccarpita
        #             #out_file => "$filename.aln",
        #         err_file    => $filename . ".STDERR",
        #         working_dir => $CLUSTER_SHARED_TEMPDIR,
        #         temp_base   => $CLUSTER_SHARED_TEMPDIR,
	#         # do not block and wait if the cluster looks full
	#         max_cluster_jobs => 1_000_000_000,
        #     }
        # );

	print STDERR "Running muscle with $filename as input, $filename.aln as output\n";
       system("muscle", "-in", $filename, "-out", "$filename.aln", "-maxiters", $maxiters);

	print STDERR "TEMPFILE = $temp_file\n";

	print STDERR "Copying $filename.aln TO $CLUSTER_SHARED_TEMPDIR\n";
	copy("$filename.aln", "$PATH");

#         my ( undef, $job_file ) =
#           tempfile( DIR => $PATH, TEMPLATE => "object_XXXXXX" );

#         store( $job, $job_file )
#           or $page->message_page(
#             "An error occurred in the serializaton of the job object");

         my $job_file_base = File::Basename::basename("$filename.aln");

#         print STDERR "SUBMITTED JOB WITH JOBID: " . $job->job_id() . "\n";
         my $cds_temp_filename = File::Basename::basename($cds_temp_file);

#         # url encode the destination pass_back page.
my $pass_back =
 "show_align.pl?title=$title&type=$type&force_gap_cds=1&cds_temp_file=$cds_temp_filename&temp_file=$job_file_base";
         #$pass_back =~ s/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg;
#         my $message =
#           "Running Muscle v3.6 ($SEQ_COUNT sequences), please wait ...";

        chdir $old_wd;

	print STDERR "Now redirecting...\n";
        $page->client_redirect($pass_back);
      

    }
}

sub convert_clustal_fasta {
    my $clustal_file = shift;
    my $fasta_file   = shift;

    my $in = Bio::AlignIO->new(
        -file   => $clustal_file,
        -format => 'clustalw'
    );
    my $cl_out = Bio::AlignIO->new(
        -file   => ">$fasta_file",
        -format => 'fasta',
    );

    while ( my $aln = $in->next_aln() ) {
        $aln->set_displayname_flat();
        $cl_out->write_aln($aln);
    }
    $cl_out->close();
    $in->close();
}

