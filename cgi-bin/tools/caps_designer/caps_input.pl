
use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;

#Get input, if this page is loaded from find_caps.pl
our $page = CXGN::Page->new( "CAPS Designer", "Chenwei");
my ($format, $cheap_only, $exclude_seq, $cutno, $seq_data, $seq_select) = $page->get_arguments("format", "cheap", "start", "cutno", "seq_data");#, "seq_select");

my ($intro_content, $input_content);

$intro_content = "<tr><td><p>This tool designs CAPS assays for up to 12 sequences.  Two types of nucleotide inputs are accepted: fasta sequences and clustal alignment.  It generates a list of polymorphic enzymes that cut the sequences into different length products.</p>";
$intro_content .= "<b>Suggestions:</b><ol><li>Low quality nucleotides and \"n\"s at both ends of a sequence generate ambiguity. Please remove them from the input sequences.</li><li>Polymorphic digested fragments of too small sizes are hard to visualize on 1-4% agarose gel, thus not suitable for CAPS experiment.  Please exclude some nucleotides (for example 20) at both ends to avoid the problem.</li></ol></td></tr>";


$input_content = '<form method="post" action="find_caps.pl" name="capsinput">';

#Select input format
$input_content .= '<b>Input format</b><br />';
if ( $format && $format eq "clustalw" ){
  $input_content .= '<input type="radio" name="format" value="clustalw" checked="checked" />clustal alignment <a target="blank" href="/about/clustal_file.pl">[What is this?]</a><br />';
  $input_content .= '<input type="radio" name="format" value="fasta" />unaligned fasta sequences<br /><br />';
}
else {
  $input_content .= '<input type="radio" name="format" value="clustalw" />clustal alignment <a target="blank" href="/about/clustal_file.pl">[What is this?]</a><br />';
  $input_content .= '<input type="radio" name="format" value="fasta" checked="checked" />unaligned fasta sequences<br /><br />';
}

{ no warnings 'uninitialized';
#Text area for input sequences
$input_content .= '<b>Input sequences</b><br />';
$input_content .= "<textarea name=\"seq_data\" rows=\"20\" cols=\"100\">$seq_data</textarea><br /><br /><br /><br />";
}

#Options low price enzyme
$input_content .= '<b>Options</b><br /><br />';
if ( $cheap_only ){
  $input_content .= '<input type="checkbox" name="cheap" value = "1" checked="checked" /> Find enzymes priced less than $65/1000u.<br />';
}
else {
  $input_content .= '<input type="checkbox" name="cheap" value = "1" /> Find enzymes priced less than $65/1000u.<br />';
}

#Option exclude end sequence
if (!$exclude_seq){
  $exclude_seq = 20;
}
$input_content .= "Exclude <input type=\"text\" size=\"3\" name=\"start\" value=\"$exclude_seq\" /> nucleotides at both ends<br />";

#Option cutting times
if (!$cutno){
  $cutno = 4;
}
$input_content .= "Don\'t show enzymes that cut each parent more than <input type=\"text\" name=\"cutno\" size=\"3\" value=\"$cutno\" /> times<br /><br /><br />";

$input_content .= '<input type="submit" name="submit" value="Find Caps" />';

$input_content .= '</form>';

#Submit and reset button
$input_content .='<form method="post" action="caps_input.pl" name="capsinput2">';
$input_content .= '<input type="submit" name="submit" value="Reset" /></form>';
$page->header();
print page_title_html("CAPS Designer");
print blue_section_html('Introduction','<table width="100%" cellpadding="5" cellspacing="0" border="0" summary="">' . $intro_content . '</table>');
print blue_section_html('Query Input', $input_content);


$page -> footer();
