#!/usr/bin/perl -w
use strict;
use warnings;

use CXGN::Page;
use CXGN::DB::Connection;
use CXGN::Login;

our @databases;

our $page = CXGN::Page->new("SGN BLAST watch","Adri");
my $dbh = CXGN::DB::Connection->new();

my $person_id=CXGN::Login->new($dbh)->verify_session();

&local_init();

$page->header('SGN BLAST Watch','SGN BLAST Watch');

print <<EOF;

<form method="post" action="submit.pl">

<table summary="" cellpadding="0" cellspacing="0" border="0" align="center">

<tr><td align="center">Submit a query to be BLASTed weekly.  You will be contacted by email when the results change.</td></tr>

<tr><td><br /></td></tr>

<tr><td><table summary="" cellpadding="0" cellspacing="0" border="0">

<tr><td width="25%"><b>Program:</b> </td><td>
<select name="program">
<option value="blastn">BLASTN (nucleotide to nucleotide)</option>
<option value="blastx">BLASTX (nucleotide to protein; query translated to protein)</option>
<option value="blastp">BLASTP (protein to protein)</option>
<option value="tblastx">TBLASTX (protein to protein; both database and query are translated)</option>
<option value="tblastn">TBLASTN (protein to nucleotide; database translated to protein)</option>
</select>
</td></tr>

<tr><td colspan="2"><br /></td></tr>

<tr><td><b>Database:</b> </td><td>

<select name="database">
@databases
</select>

</td></tr>
    
<tr><td colspan="2"><br /></td></tr>
    
<tr><td colspan="2" align="center"><b>Query sequence</b></td></tr>
   
<tr><td colspan="2" align="center" class="fix">
<textarea name="sequence" rows="8" cols="80"></textarea>
</td></tr>
    
<tr><td colspan="2"><br /></td></tr>
    
<tr><td><b>Substitution Matrix:</b> </td><td>
<select name="matrix">
<option value="BLOSUM62">BLOSUM62 (default)</option>
<option value="BLOSUM80">BLOSUM80 (recent divergence)</option>
<option value="BLOSUM45">BLOSUM45 (ancient divergence)</option>
<option value="PAM30">PAM30</option>
<option value="PAM70">PAM70</option>
</select>
</td></tr>
    
<tr><td colspan="2"></td></tr>

<tr><td><b>Expect (e-value) Threshold:</b> </td><td>
<input type="text" size="6" value="1.0" name="evalue" />
</td></tr>

<tr><td>
<input type="hidden" value="$person_id" name="sp_person_id" />
</td></tr>

</table>

</td></tr>

<tr><td><br /></td></tr>

<tr><td align="center">
<input type="reset" name="clear" value="Clear" />
<input type="submit" name="submit" value="Submit" />
</td></tr>

</table>

</form>

<br /><br />

EOF

$page->footer();


sub local_init {

  # This is hard-coded here, but ought to be stored in the database (it was in
  # old SGN), in a way that is automatically updated when the files on disk are
  # updated -- so this script is always in sync. Can't do that now.

  @databases = 
    ( '<optgroup label="Markers">',
      '<option value="markers/marker_sequences.fasta">All SGN markers</option>',
      '</optgroup>',
      '<optgroup label="Tomato Genome">',
      '<option value="bacs/tomato_bac_ends">Tomato BAC ends</option>',
      '<option value="bacs/tomato_bacs">Tomato full BAC sequences</option>',
      '<option value="repeats/mips_repeat_collection">MIPS tomato repeat collection</option>',
      '<option value="repeats/TIGR_SolAth_repeat">TIGR tomato/arabidopsis repeats</option>',
      '</optgroup>',
      '<optgroup label="SGN ESTs">',
      '<option value="estdb/all_ests">All SGN ESTs</option>',
      '<option value="estdb/lycopersicon-all">Tomato ESTs</option>',
      '<option value="estdb/Solanum_tuberosum">Potato ESTs</option>',
      '<option value="estdb/Capsicum">Pepper ESTs</option>',
      '<option value="estdb/Solanum_melongena">Eggplant ESTs</option>',
      '<option value="estdb/Petunia_hybrida">Petunia ESTs</option>',
      '</optgroup>',
      '<optgroup label="SGN unigenes">',
      '<option value="unigene/all_current" selected="selected">All SGN unigenes</option>',
      '<option value="unigene/Lycopersicon_combined">Tomato (lycopersicon combined) unigene</option>',
      '<option value="unigene/Solanum_tuberosum">Potato (Solanum tuberosum) unigene</option>',
      '<option value="unigene/Capsicum_combined">Pepper (Capsicum combined) unigene</option>',
      '<option value="unigene/Solanum_melongena">Eggplant (Solanum melongena) unigene</option>',
      '<option value="unigene/Petunia_hybrida">Petunia (Petunia hybrida) unigene</option>',
      '<option value="unigene/Coffea_canephora">Coffee (Coffea canephora) unigene</option>',
      '</optgroup>',
      '<optgroup label="Arabidopsis (TAIR)">',
      '<option value="ath1/ATH1_pep">Arabidopsis proteins</option>',
      '<option value="ath1/ATH1_seq">Arabidopsis gene models (nt.)</option>',
      '<option value="ath1/ATH1_cds">Arabidopsis coding sequence (nt. - no introns, no UTRs)</option>',
      '<option value="ath1/ATH1_bacs_con">Arabidopsis finished BAC sequences</option>',
      '</optgroup>',
      '<optgroup label="Other">',
      '<option value="genbank/nr">Genbank non-redundant protein database (NR)</option>',
      '<option value="misc/swissprot">Swissprot full-length, annotated, protein database</option>',
      '</optgroup>'
 );
  
}

