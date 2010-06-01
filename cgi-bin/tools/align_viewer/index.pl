use strict;

use SGN::Context;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;
use HTML::Entities;
#Get input, if this page is loaded from find_caps.pl
our $page = CXGN::Page->new( "Align Browser", "Chenwei");
my ($seq_data, $id_data, $format, $title, $type, 
	$show_prot_example, $show_cds_example, $show_id_example,
	$temp_file, $maxiters
	) = 
	$page->get_arguments(
	"seq_data", "id_data", "format", "title", "type", 
	"show_prot_example", "show_cds_example", "show_id_example",
	"temp_file", "maxiters"
	);

my ($intro_content, $input_content);

my $vhost_conf = SGN::Context->new();
our $HTML_ROOT = $vhost_conf->get_conf('basepath');
our $DOC_PATH =  $vhost_conf->get_conf('tempfiles_subdir').'/align_viewer';
our $PATH = $HTML_ROOT . $DOC_PATH;
unless($temp_file =~ /\//){
	$temp_file = $PATH . "/" . $temp_file;
}

if(-f $temp_file){
	open(FH, $temp_file);
	$seq_data .= $_ while (<FH>);
	close(FH);
}


#############################################################
#Create introduction content'
$intro_content = <<HTML;
<p>This tool analyzes sequence alignment.  Please input <b>aligned sequences only</b>, in either fasta or clustal format.</p>
Its functionality includes:
<ol>
<li>Image display.</li>
<li>Calculation and output of pairwise similaity and putative splice variant or allelle pairs based on overlap and similarity between sequence pairs in an alignment.</li>
<li>Provides the user with options to hide some alignment sequences so that they are not included in the analysis.</li>
<li>Select a range of sequences to be analyzed.</li>
<li>Assess how an alignment member overlap with other members.</li>
<li>Calculate the non-gap mid point of each align sequence and group the sequences according to their overlap.</li>
</ol>
HTML

$title||="";

#############################################################
#Create input content
$input_content = <<HTML;
<form method="post" action="show_align.pl" name="aligninput" enctype="multipart/form-data">

<input type="submit" name="submit" value="Analyze Alignment" /><br /><br />
<b>Title (optional): </b>&nbsp;&nbsp;
<input type="textbox" name="title" size="16" value="$title">
<br /><br />
HTML

#Alignment type
if(!$type) { $type = "pep" }
my %type_checked = ( pep => "", nt => "", cds => "" );
$type_checked{$type} = "checked=\"checked\"";
my ($tcn, $tcp, $tcc) = map { $type_checked{$_} } qw/ nt pep cds /;

$input_content .= <<HTML;
<b>Type</b>&nbsp;&nbsp;
<input id="aligninput.radio.nt" type="radio" name="type" value="nt" $tcn/>nucleotide &nbsp;&nbsp;
<input id="aligninput.radio.pep" type="radio" name="type" value="pep" $tcp/>peptide &nbsp;&nbsp;
<input id="aligninput.radio.pep" type="radio" name="type" value="cds" $tcc/>CDS (most powerful)
<br /><br />
HTML

#############################
#Input format let it be unaligned by default
if (!$format) { $format="fasta_unaligned"; }

my %format_checked = ( clustalw => "",
		fasta => "",
		fasta_unaligned => "",
		);

$format_checked{$format}="checked=\"checked\"";
$maxiters ||= 2;
my ($fcw, $fcf, $fcu) = map { $format_checked{$_} } qw/clustalw fasta fasta_unaligned/;

$input_content .= <<HTML;
<b>Input format</b><br />
You may specify the species of the sequence with a forward slash, e.g. "AT1G01010.1/Arabidopsis" <br /> 
Make sure all the spaces in the id and species are replaced by '_'.<br />
<input type="radio" name="format" value="clustalw" $fcw/>Clustal Alignment<a target="blank" href="/about/clustal_file.pl"> [What is this?]</a><br />
<input type="radio" name="format" value="fasta" $fcf/>Fasta Alignment (With Gaps)<br /><br />
<input type="radio" name="format" value="fasta_unaligned" $fcu/>Fasta Unaligned (Will be aligned with <a href="http://www.drive5.com/muscle/">Muscle 3.6</a>, Limited to 200 Sequences)<br />

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Max Iterations 
<input type="text" name="maxiters" value=$maxiters>
 Use more iterations for greater accuracy. The maximum is 1000.<br /><br />
<!--
<input type="radio" name="run" value="cluster" checked="1">run on cluster (preferred)<br />
<input type="radio" name="run" value="local">run on localhost<br /><br />
-->
HTML

if($show_prot_example){
	$seq_data = seq_from_file($page->path_to("cgi-bin/tools/align_viewer/data/prot_example.txt"));
}
elsif($show_cds_example){
	$seq_data = seq_from_file($page->path_to("cgi-bin/tools/align_viewer/data/cds_example.txt"));
}
elsif($show_id_example){
	$id_data = <<HEREDOC;
SGN-U282881 SGN-U228103 At1g09155.1 At1g56240.1 At1g56250.1 NP_178331.2 At2g02350.1 At2g02320.1 At2g02340.1 At2g02360.1 At2g02250.1 At2g02240.1 At2g02300.1 At2g02310.1 SGN-U211584 SGN-U219097 SGN-U219098 SGN-U311800 SGN-U218282 SGN-U218283 At5g24560.1 SGN-U204215 SGN-U221580 SGN-U282885 SGN-U234276 SGN-U220091 SGN-U305684 SGN-U219720
HEREDOC
}

$seq_data ||= '';
###############################
#Text area for input sequences
$input_content .= <<HTML;
<b>Input fasta/clustal sequences</b>
&nbsp;&nbsp;
<a href="index.pl" onclick="
	document.getElementById('textarea_seq_data').value = '';
	return false">(x) Clear</a><br />
<textarea id="textarea_seq_data" name="seq_data" rows="12" cols="80">$seq_data</textarea><br /><br />
<b>Or use identifiers, separated by spaces</b><br />
 Supports TAIR AGI [AT1G01010.1], SGN Unigene [SGN-U332332], or any NCBI/Entrez identifier<br />
<textarea id="textarea_id_data" name="id_data" rows="2" cols="80">$id_data</textarea><br /><br />
<b>Or upload a fasta/clustal file</b> <input type="file" name="upload" /><br />
<br /><br />


<input type="submit" name="submit" value="Analyze Alignment" />
</form>

HTML


# Print Page

$page->header();


my $example_link = <<HTML;
&nbsp;&nbsp;&nbsp;<span style="color:#669">
<a href="index.pl?&format=fasta&title=Alignment%20Example&type=pep&show_prot_example=1">
Aligned Example</a>
&nbsp;|&nbsp;
<a href="index.pl?&format=fasta_unaligned&maxiters=300&title=CDS%20Example&type=cds&show_cds_example=1">Unaligned Example</a>
&nbsp;|&nbsp;
<a href="index.pl?&maxiters=10&title=ID%20Input%20Example&&type=pep&format=fasta_unaligned&show_id_example=1">ID Input Example</a>
</span>
HTML

print page_title_html("Alignment Analyzer");

#print blue_section_html('Introduction','<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $intro_content . '</td></tr></table>');

print blue_section_html(
	"<span style=\"white-space:nowrap\">Query Input &nbsp;&nbsp;&nbsp;&nbsp;$example_link</span>",
	'<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $input_content . '</td></tr></table>');


$page->footer();


sub seq_from_file {
	my $file = shift;
	my $seq = "";
	open(FH, $file) or return "File not found";
	$seq .= $_ while(<FH>);
	close FH;
	return $seq;
}
