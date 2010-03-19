use strict;
use warnings;
use CXGN::Page;
use CXGN::Genomic::Chromat;
use CXGN::Genomic::BlastQuery;

use CXGN::Page::FormattingHelpers
    qw(
       info_section_html
       page_title_html
       info_table_html
       html_break_string
       html_string_linebreak_and_highlight
      );

use CXGN::DB::Connection;

use CXGN::MasonFactory;

#TODO:
#  add link to show the quality scores

########### CONFIGURATION VARIABLES #########

my $clone_info_page = '/maps/physical/clone_info.pl';
my $chromat_view_page = '/maps/physical/clone_chromat.pl';

#############################################

our $page = CXGN::Page->new( 'Clone Read Details', 'Rob Buels');

my ($arg_cid) = $page->get_encoded_arguments('chrid');
$arg_cid += 0;
($arg_cid > 0) || $page->error_page('Invalid arguments');

### look up info from DB ###
my $dbh = CXGN::DB::Connection->new('genomic'); 

my $chromat = CXGN::Genomic::Chromat->retrieve($arg_cid)
    or $page->error_page("No chromatogram found with id $arg_cid");
my $clone = $chromat->clone_object;
my $gss = $chromat->latest_gss_object;
my $qcreport = $gss ? $gss->qc_report_object : undef;

###output the HTML

#page title
$page->header('Genomic Clone End Sequence');
print page_title_html('Clone Read '.$chromat->clone_read_external_identifier);

#chromatogram and sequencing information
my $chromat_html = chromat_summary_html($chromat,'/search/trace_download.pl?chrid='.$chromat->chromat_id);
print info_section_html(title => 'Sequence Read', contents => $chromat_html);

#Sequence and quality information
my $badwarning = (! $qcreport || $qcreport->hqi_length < 150 || scalar(%{$gss->flags}) != 0)
                 ? '<center><span style="color: red; font-weight: bold">This is probably not a useful sequence.</span></center><br />'
                 : '';
print info_section_html(title => 'Sequence',
			contents =>
			($gss ? gss_summary_html($gss) : '<div class="warning">No basecalled sequence found.  The chromatogram file is probably corrupt.</div>')
			."<br />$badwarning"
			.($qcreport ? qcreport_summary_html($qcreport)
			 : '<span class="ghosted">No quality report found.</span>')
		       );

#BLAST annotation information

#look up any stored blast hits for this BAC-end
my $blasthits_html = '';

if($gss && $qcreport) {

  #get all the hits associated with this GSS
  my @hits =
    map { ( $_->blast_hit_objects(2) ) }
      CXGN::Genomic::BlastQuery->for_gss($gss);

#   use Data::Dumper;
#   die Dumper(\@hits);

  foreach (@hits) {
    $blasthits_html .= $_->summary_html;
  }
}
$blasthits_html ||= '<div class="ghosted">No automatic annotations found.</div>';
print info_section_html(title => 'Sequence Annotations',
			contents =>
			info_table_html('Automatic Annotations' => $blasthits_html,
					'Manual Annotations'    => qq{<div class="ghosted">No manual annotations found.</div>},
					__border => 0,
				       )
		       );

#BAC summary information
my $clone_html = "<a style=\"font-size:larger; font-weight: bold; line-height: 1.1\" href=\"$clone_info_page?id=".$clone->clone_id.'">Clone '.$clone->arizona_clone_name.'</a>';
$clone_html .=
  '<table><tr><td>'
  . CXGN::MasonFactory->bare_render('/genomic/clone/clone_summary.mas', clone => $clone )
  .'</td><td>'
  . CXGN::MasonFactory->bare_render('/genomic/library/library_summary.mas', library => $clone->library_object)
  .'</td></tr></table>';

$clone_html .= qq{<br />\n<span class="fieldname">Other Reads:</span>\n<br />\n};
my @otherchromats = grep {$chromat->chromat_id != $_->chromat_id} $clone->chromat_objects;
$clone_html .= @otherchromats
    ? info_table_html( scalar(@otherchromats).' sequencing reads found' => 
		       qq|<ul style="list-style: none">\n|
		       .join("\n", map { '<li>'
					     .$_->read_link_html($page->{request}->uri)
					     ."</li>\n"
				       } @otherchromats
			    )
		       ."</ul>\n",
		       __border => 0,
                     )
    : '<div class="ghosted">No sequence reads found.</div>';
print info_section_html(title => 'BAC', contents => $clone_html);

$page->footer();


=head2 gss_summary_html

  Desc: make an HTML summary of a GSS
  Args: a CXGN::Genomic::GSS object
  Ret : string of HTML containing this sequence's vital statistics
  Side Effects: none
  Example:
    print $gss->summary_html;

=cut

sub gss_summary_html {
    my $gss = shift;
    my $qc = $gss->qc_report_object;

    my $trimmed_len = $qc ? $qc->hqi_length : 0;
    my $untrimmed_len = length($gss->seq);
    my $version = $gss->version;

    my $seq_fasta_header = '>'.$gss->external_identifier;

    #find genbank accession
    my @submissions = $gss->gss_submitted_to_genbank_objects;
    my ($genbanksub) = grep {$_->genbank_identifier} @submissions;

    my $prettyseq = html_highlighted_seq($gss,'badseq',100);
    my $hqiseq = html_break_string($gss->trimmed_seq,100);

    my $info_html = info_table_html( __border => 0,
				     Version => "$version (current)",
				     'Length (bp)' => "$trimmed_len trimmed for vector and quality, $untrimmed_len raw",
				     $genbanksub ? ('Genbank Accession' => '<a href="http://www.ncbi.nlm.nih.gov/gquery/gquery.fcgi?term='.$genbanksub->genbank_identifier.'">'.$genbanksub->genbank_identifier.'</a>') : (),
				     __multicol => 3,
				   );

    my $sequence_html = info_table_html( __border => 0,
					 __tableattrs => 'width="100%"',
					 Sequence => <<EOH );
<div align="right">
  <a href="#_" id="trimmedseq_link" class="optional_show" onclick="dswitch('rawseq','trimmedseq')">Show Raw Sequence</a>
  <a href="#_" id="rawseq_link" class="optional_show_active" onclick="dswitch('trimmedseq','rawseq')">Show Raw Sequence</a>
</div>
<div id="rawseq" class="sequence">
$seq_fasta_header (raw untrimmed)<br />
$prettyseq
</div>
<div id="trimmedseq" class="sequence">
$seq_fasta_header (trimmed for quality and cloning vector)<br />
$hqiseq
</div>
EOH


    return <<EOH;
<script language="JavaScript" type="text/javascript">
function dswitch(id1,id2) {
  var elem1 = document.getElementById(id1);
  var link1 = document.getElementById(id1+'_link');
  var elem2 = document.getElementById(id2);
  var link2 = document.getElementById(id2+'_link');
  elem1.style.display = 'block';
  link1.style.display = 'inline';
  elem2.style.display = 'none';
  link2.style.display = 'none';
}
</script>

$info_html

$sequence_html

<script language="JavaScript" type="text/javascript">
dswitch('trimmedseq','rawseq');
</script>
EOH

}


=head2 qcreport_summary_html

  Args: a CXGN::Genomic::QCReport object
  Ret : string of HTML that gives a summary of this QCReport's
        vital statistics
  Side Effects: none
  Example:

  print $qcreport->summary_html;

=cut

sub qcreport_summary_html {
    my $qcr = shift;
    my $gss = $qcr->gss_object;

    my $processedby = 'SGN';  #change this for the attribution framework

    my $sig = $qcr->vecsig
      or die "Unknown vs_status ".$qcr->vs_status;

    my $flags_html = $gss->flags_html;

    return $flags_html."\n"
      .info_table_html( __title                  => 'Quality Report',
			__multicol               => 5,
			'Processed&nbsp;by'      => 'SGN',
			'Vector signature'       => $qcr->vecsig,
			'Quality trim threshold' => $qcr->qual_trim_threshold,
			'Sequence entropy'       => $qcr->entropy || 'not recorded',
			'Expected error&nbsp;%'  => $qcr->expected_error ? $qcr->expected_error*100 : 'not recorded',
		      );
}


=head2 chromat_summary_html

  Desc:	print HTML summary of this chromatogram
  Args:	CXGN::Genomic::Chromat object,
        (optional), a URL where this chromatogram can be downloaded
  Ret :	HTML summary of the chromatogram, with a 'download' link if you
        provided a download URL

=cut

sub chromat_summary_html {
    my $chr = shift;
    my $downloadurl = shift;
    my $facilityID = $chr->filename;

    my $view_link = '';
    my $dl_link = $facilityID && $downloadurl ? '[<a href="'.$downloadurl.'">download</a>]'
                                              : '<span class="ghosted">not availabe for<br />direct download</span>';

    info_table_html(#__title => 'Sequence Read',
		    __multicol => 5,
		    'Read Class' => $chr->read_class_object->class_name,
		    'Read ID' => $chr->clone_read_external_identifier,
		    'Primer'  => $chr->primer,
		    'ID from Seq. Facility' => $chr->filename || '<span class="ghosted">not recorded</span>',
		    $dl_link 
		    ? ('Chromatogram'  => $dl_link)
		    : (), 
		    __border => 0,
		   );

}


=head2 html_highlighted_sequence

  Desc: get an HTML representation of this GSS's sequence, with trimmed-out
        regions highlighted with
        L<CXGN::Page::FormattingHelpers::html_string_linebreak_and_highlight>
  Args: (  (optional) highlight class (default 'badseq'),
           (optional) line width  (default 100),
        )
  Ret : HTML containing pretty sequence
  Side Effects: none
  Example:
     my $hiseq = $gss->html_highlighted_seq;
     print html_optional_show('Raw Sequence',$hiseq);

=cut

sub html_highlighted_seq {
    my $this = shift;
    my $highlightclass = shift || 'badseq';
    my $breakwidth = shift || 100;
    my @trimmedregions = $this->trimmed_regions;
    return html_string_linebreak_and_highlight($this->seq,\@trimmedregions,
					       $highlightclass,$breakwidth);
}
