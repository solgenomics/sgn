#!/usr/bin/perl -w
use strict;
use CXGN::Page;
use CXGN::Garbage::Sequence;
use CXGN::Page::FormattingHelpers qw/page_title_html blue_section_html html_break_string/;
use CXGN::DB::Connection;


our $page = CXGN::Page->new( "Simple N->AA Translate", "Dan/Koni");
my $dbh = CXGN::DB::Connection->new();

my $memberq = $dbh->prepare_cached("SELECT nr_members FROM unigene WHERE unigene_id=?");
my $consensusq = $dbh->prepare_cached("SELECT seq FROM unigene INNER JOIN unigene_consensi USING (consensi_id) WHERE unigene_id=?");
my $unigene_estq = $dbh->prepare_cached("SELECT COALESCE(SUBSTRING(seq, hqi_start::integer+1, hqi_length::integer), seq) FROM unigene LEFT JOIN unigene_member USING (unigene_id) LEFT JOIN est USING (est_id) LEFT JOIN qc_report USING (est_id) WHERE unigene.unigene_id=?");
my $estq  = $dbh->prepare_cached("SELECT COALESCE(SUBSTRING(seq, hqi_start::integer+1, hqi_length::integer), seq) FROM est LEFT JOIN qc_report USING (est_id) where est.est_id=?");


my ($seq, $est_id, $unigene_id) = 
  $page->get_encoded_arguments("seq", "est_id", "unigene_id");

my ($seqid,$sequence) =split('#',$seq);

if (! $sequence) {

  my $sth;
  if ($est_id) {
    $seqid = "SGN-E$est_id";

    $estq->execute($est_id);
    if ($estq->rows == 0) {
      $page->error_page("Internal reference not found ($est_id)");
    }

    ($sequence) = $estq->fetchrow_array();

  } elsif ($unigene_id) {
    $seqid = "SGN-U$unigene_id";

    $memberq->execute($unigene_id);
    if ($memberq->rows == 0) {
      $page->error_page("Internal Reference (SGN-U$unigene_id) not found");
    }

    my ($nr_members) = $memberq->fetchrow_array();
    if ($nr_members > 1) {
      $consensusq->execute($unigene_id);
      ($sequence) = $consensusq->fetchrow_array();
    } else {
      $unigene_estq->execute($unigene_id);
      ($sequence) = $unigene_estq->fetchrow_array();
    }

  } else {
    invalid_search($page);
  }

}

#cleanup sequence format
#see the FASTA format description for the choice of letters
        $sequence=~tr/-ACGTURYKMSWBDHVN//cd;


my (@frames, @frames_translation, @frames_trans_toprint);


my ($i,$j);

#translate in first 3 frames
for ($j=0;$j<3;$j++){
    $frames[$j]=$sequence;
    substr($frames[$j],0,$j,'');
    my $i=0;
    for (;$i<(length $frames[$j]);$i+=3){
	$frames_translation[$j].=CXGN::Garbage::Sequence::translate_3n_1letter(substr($frames[$j],$i,3));
    }
}

#invert and complement
my $complement;
for ($i=((length $sequence)-1);$i>=0;$i--){
    $complement.=substr($sequence,$i,1);
}
$complement=~tr/ACTG/TGAC/;


#translate in reversed 3 frame
for ($j=3;$j<6;$j++){
    $frames[$j]=$complement;
    substr($frames[$j],0,($j-3),'');
    for ($i=0;$i<(length $frames[$j]);$i+=3){
	$frames_translation[$j].=CXGN::Garbage::Sequence::translate_3n_1letter(substr($frames[$j],$i,3));
    }
}

#select the "best" reading frame.
#right now the only criteria is "longest stretch without a stop code"
my @longest_stretch;
for ($j=0;$j<@frames_translation;$j++){
    my $stretch=0;
    $i=0;
    $longest_stretch[$j]=0;
    while ($i>=0){
	my $current=index ($frames_translation[$j],'*',$i+1);
	if ($current==-1){
	    $stretch= (length $frames_translation[$j]) - $i;
	}
	else{
	    $stretch=$current-$i;
	}
	$longest_stretch[$j]<$stretch
	    and $longest_stretch[$j]=$stretch;
	$i=$current;
    }
}
my ($longest_stretch,$longest_stretch_frame)=(0,0);
for ($j=0;$j<@longest_stretch;$j++){
    if($longest_stretch<$longest_stretch[$j]){
	$longest_stretch=$longest_stretch[$j];
	$longest_stretch_frame=$j;
    }
}





@frames_trans_toprint=@frames_translation;

for ($j=0;$j<@frames_trans_toprint;$j++){
#     for ($i=80;$i<(length $frames_trans_toprint[$j]);$i+=85){
# 	substr($frames_trans_toprint[$j],$i,0,"<br />\n");
#    }
  $frames_trans_toprint[$j] = html_break_string($frames_trans_toprint[$j],84);
  $frames_trans_toprint[$j]=~s|\*|<span style="font-weight: bold; color: #0000FF">*</span>|g;
  $frames_trans_toprint[$j]=~s|M|<span style="color: #0000FF">M</span>|g;
  $frames_trans_toprint[$j]=~s|X|<span style="color: #FF0000">X</span>|g;
};


my $translation_html = qq{<table>\n};
for ($j=0;$j<@frames_trans_toprint;$j++){
    my $cell_background='';
    $longest_stretch_frame==$j
	and $cell_background='class="bgcolorselected"';
    my $frame_nr=$j+1;
    if ($frame_nr > 3){
	$frame_nr-=3;
	$frame_nr='-'.$frame_nr;
    }
    else{
	$frame_nr='+'.$frame_nr;
    }
    $translation_html .= <<EOH;
<tr valign="top">
  <th>$frame_nr:</th>
  <td $cell_background><tt>$frames_trans_toprint[$j]</tt></td>
  <td><form action="/tools/blast/" method="post" name="Blas">
        <input type="hidden" name="seq" value=">$seqid, translation in frame $frame_nr 
$frames_translation[$j]" />
        <input type="submit" name="SUBMIT" value="Blast" /></form>
  </td>
</tr>
EOH
}
$translation_html .= "</table>\n";

$page->header();
print page_title_html("Six-Frame Translation &mdash; $seqid");
print blue_section_html('Nucleotide Sequence','<div class="sequence">'
			                      .html_break_string($sequence,95)
			                      .'</div>');
print blue_section_html('Six-Frame Translation',$translation_html);
print <<EOF;

<p style="margin: 1em">
<span style="color: gray">Note: This is a simple six frame translation. Correction for frame shifting sequencing errors (insertion/deletion) has not been performed. Isolation of 5' UTR or 3' UTR has also not been performed. The highlighted frame has the longest open reading frame, measuring from the first methionine encountered.</span>
</p>
EOF

$page->footer();

sub invalid_search {
    my ($page) = @_;

  $page->header();

print <<EOF;

<h4>INVALID SEARCH</h4>

<p>This request specified no sequence or identifier to use for translation</p>
EOF

  $page->footer();
    exit(0);
}

