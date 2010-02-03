#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html
                                       html_break_string
                                    /;
use CXGN::DB::Connection;
use CXGN::Transcript::Unigene;
use CXGN::Transcript::CDS;
use Bio::Seq;

my $page = CXGN::Page->new( "ESTScan Details", "Chenwei Lin");
my ($unigene_id) = $page->get_encoded_arguments("unigene_id");


my $dbh = CXGN::DB::Connection->new();


my $unigene = CXGN::Transcript::Unigene->new($dbh, $unigene_id);
my $unigene_seq = uc($unigene->get_sequence());
my @cds = $unigene->get_cds_list(); ##gets list of cds ids associated with the given unigene_id

my $estscan_pep_content = "";
my $estscan_clean_cds_content = "";
my $estscan_edit_cds_content = "";
my $direction_content = "";
my $score_content = "";


foreach my $c (@cds) { 
    if ($c->get_method() eq "estscan") { 
	my $seq_text = $c->get_seq_text();
	my $seq_edits = $c->get_seq_edits();
	my $protein_seq = $c->get_protein_seq();
	my $begin = $c->get_begin();
	my $end = $c->get_end();
	my $direction = $c->get_direction();
	my $score = $c->get_score();
	
	$estscan_pep_content = html_break_string($protein_seq,90);
	$estscan_clean_cds_content = html_break_string($seq_edits,90);
	$estscan_pep_content = qq{<tr><td class="sequence">$estscan_pep_content</td></tr>};
	$estscan_clean_cds_content = qq{<tr><td class="sequence">$estscan_clean_cds_content</td></tr>};
	$direction_content = ($direction eq 'F') 
	    ? '<tr><td>Forward</td></tr>'
	    : '<tr><td>Reverse</td></tr>';
	
	$score_content = "<tr><td>$score</td></tr>";

	$estscan_edit_cds_content = reformat_unigene_sequence_with_edits($c,$unigene_seq, $direction, $begin, $end, $seq_text);
	
    }
}

my $note_content = <<EOH;
<br /><span style="color: blue">ACTGX</span><span style="color: gray"> -- Inserted by ESTScan</span>
<br /><span style="color: red">actgn</span><span style="color: gray"> -- Deleted by ESTScan</span>
<br /><span style="color: gray">ACTGN</span><span style="color: gray"> -- UTR Deleted by ESTScan</span>
<br />
EOH

$page->header();
print page_title_html("ESTScan Details for Unigene SGN-U$unigene_id");
print blue_section_html('Score','<table width="100%" cellpadding="0" cellspacing="0" border="0">'.$score_content.'</table>');
print blue_section_html('Direction', '<table width="100%" cellpadding="0" cellspacing="0" border="0">'.$direction_content.'</table>');
print blue_section_html('Predicted Peptide Sequence','<table width="100%" cellpadding="0" cellspacing="0" border="0">'.$estscan_pep_content.'</table>');
print blue_section_html('Predicted Coding Sequence','<table width="100%" cellpadding="0" cellspacing="0" border="0">'.$estscan_clean_cds_content.'</table>');
print blue_section_html('Edits in Original Sequence','<table width="100%" cellpadding="0" cellspacing="0" border="0">'.$estscan_edit_cds_content.'<tr><td>'. $note_content.'</td></tr>'.'</table>');


$page->footer();

sub empty_search {

  $page->header();

  print <<EOF;
  <br />
  <b>No unigene search criteria specified</b>

EOF

  $page->footer();

  exit 0;
}

sub invalid_search {
  my ($unigene_id) = @_;

  $page->header();

  print <<EOF;
  <br />
  <b>The specified unigene identifer ($unigene_id) does not result in a valid search.</b>

EOF

  $page->footer();
  exit 0;

}

sub reformat_unigene_sequence_with_edits {

    my $self = shift;
    my $unigene_seq = shift;
    my $direction = shift;
    my $begin = shift;
    my $end = shift;
    my $seq_text = shift;
    my $estscan_edit_cds_content = "";

    #correctly gets reverse compliment of a unigene sequence
    if ($direction eq 'R'){
	my $u = Bio::Seq->new();
	$u->seq($unigene_seq);
	my $rc = $u->revcom();
	$unigene_seq = $rc->seq();
    }
    my $up_seq = substr($unigene_seq, 0, ($begin-1));
    my $down_seq = substr($unigene_seq,$end);

    $down_seq =~ s/\s//g;
    $up_seq =~ s/\s//g;
    $seq_text =~ s/\s//g;
	
    $seq_text = "${up_seq}(5')${seq_text}(3')${down_seq}";
    $estscan_edit_cds_content = html_break_string($seq_text,90);

    #my @text_components = split /\(5'\)|\(3'\)/,$estscan_edit_cds_content; ##doesn't split if the (5') or (3') markers are split on two lines
    my @text_components = split /5|3/,$estscan_edit_cds_content;


	##Color the edited nucleotides
    foreach my $comp (@text_components) {
	$comp =~ s/[\(\)\']//g;
	$comp =~ s!([actgn])!<span style="color: red">$1</span>!g; 
	$comp =~ s!X!<span style="color: blue">X</span>!g; 
	$comp ||= '';
    }

    $estscan_edit_cds_content = qq{<span style="color: gray">$text_components[0]</span>(5')$text_components[1](3')<span style="color: gray">$text_components[2]</span>};
	
    $estscan_edit_cds_content = qq{<tr><td class="sequence">$estscan_edit_cds_content</td></tr>};

    return $estscan_edit_cds_content;

}

