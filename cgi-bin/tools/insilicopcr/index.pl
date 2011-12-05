=head1 NAME

index.pl - In Silico PCR web interface

=head1 DESCRIPTION

This interface shows a form that requires user input of the forward primer,
reverse primer, maximum product size, Allowed mismathces. Also, In Silico 
PCR is dependent on the BLAST similarity search. Part of the blast code was 
used here to get the database, program, matrix, e-value. 
This page will forward the input to pcr_blast_result.pl and will then display
the results in view_result.pl.


=head1 DEPENDENCIES

Alot of the BLAST code in /sgn/cgi-bin/tool/blast was reused here
PCR is dependent on the BLAST search to find the primers in the databases

=head1 AUTHOR

Waleed Haso wh292@cornell.edu 
Only added modifications to support the PCR part 
Original code was aspired from BLAST. 

=cut



use strict;
use warnings;
use POSIX;

use CXGN::DB::Connection;
use CXGN::Page;
use CXGN::BlastDB;
use CXGN::Page::FormattingHelpers qw/page_title_html info_table_html hierarchical_selectboxes_html /;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/evens distinct/;

my $page = CXGN::Page->new("In Silico PCR form","Waleed");
my $dbh = CXGN::DB::Connection->new;
our $prefs = CXGN::Page::UserPrefs->new( $dbh );

$page->header('In Silico PCR');

my ($databases,$programs,$programs_js) = blast_db_prog_selects();

##############################################################################################################################

print page_title_html("In Silico PCR");



  print <<EOF;

<HR></HR>
<form method="post" action="pcr_blast_result.pl" name="PCRform" enctype="multipart/form-data">
   <input type="hidden" name="outformat" value="8" />
  
  <table id="PCRinput" align="center" summary="" cellpadding="0" cellspacing="15" border="0">
	<tr>
    	<td>
    		<H2><B> PCR Primers:</B></H2>
    	</td>
    </tr>
	<tr>
		<td>
    		<B> Forward Primer</B>
    	</td>
    	<td>
    		<input type="text" size="65" value="" name="fprimer" />
    	</td>
    </tr>
	<tr>
		<td>
    		<B>Reverse Complement Forward Primer</B>
    	</td>
    	<td>
			<input type="checkbox" name="frevcom" />
    	</td>
    </tr>
	<tr>
		<td>
    		<B> Reverse Primer</B>
    	</td>
    	<td>
    		<input type="text" size="65" value="" name="rprimer" />
    	</td>
    </tr>
	<tr>
		<td>
    		<B>Reverse Complement Reverse Primer</B>
    	</td>
    	<td>
			<input type="checkbox" name="rrevcom" />
    	</td>
    </tr>
    <tr>
    	<td>
    		<b>Product Maximum Length</b> 
    	</td>
        <td >
        	<input type="text" size="5" value="5000" name="productLength" />
        </td>
    </tr>
    <tr>
    	<td>
    		<b>Allowed Mismatches</b> 
    	</td>
        <td >
        	<input type="text" size="5" value="0" name="allowedMismatches" />
        </td>
    </tr>
    <tr>
    	<td>
    		<H2><B> BLAST Attributes:</B></H2>
    	</td>
    </tr>
    
    <tr>
    	<td>
    		<b>Database (<tt>-d</tt>)</b> 
        </td>
        <td>
        	$databases <a style="font-size: 80%" title="View details of each database" href="/tools/blast/dbinfo.pl">db details</a>
        </td>
    </tr>
    <tr>
    	<td>
    		<b>BLAST Program (<tt>-p</tt>)</b> 
    	</td>
    	<td>
    		$programs
    	</td>
    </tr>
    <tr>
    	<td>
    		<b>Substitution Matrix (<tt>-M</tt>)</b>
    	</td>
        <td >
            <select name="matrix">
            <option value="BLOSUM62">BLOSUM62 (default)</option>
            <option value="BLOSUM80">BLOSUM80 (recent divergence)</option>
            <option value="BLOSUM45">BLOSUM45 (ancient divergence)</option>
            <option value="PAM30">PAM30</option>
            <option value="PAM70">PAM70</option>
            </select>
        </td>
    </tr>
    <tr>
    	<td>
    		<b>Expectation value (<tt>-e</tt>)</b> 
    	</td>
        <td >
        	<input type="text" size="10" value="0.01" name="expect" />
        </td>
    </tr>
    <tr><td><b>Filter query sequence (DUST with blastn, SEG with others) (<tt>-F</tt>)</b></td>
        <td><input type="checkbox" checked="checked" name="filterq" /></td>
    </tr>
    <tr>
    	<td align="right"><input type="reset" value="Clear" /></td>
    	<td align="center"><input type="submit" name="search" value="  Run  " style="background: yellow; font-size: 130%" /></td>
    </tr>
  </table>
</form>
<script language="JavaScript" type="text/javascript">
$programs_js
</script>
EOF

#}#end of the commented else

$page->footer();

##########################################################################################################################
#This subroutine is copied exactly from the BLAST index.pl code

sub blast_db_prog_selects {
  sub opt {
    my $db = shift;
    my $timestamp = $db->file_modtime
      or return '';
    $timestamp = strftime(' &nbsp;(%m-%d-%y)',gmtime $db->file_modtime);
    my $seq_count = $db->sequences_count;

    [$db->blast_db_id, $db->title.$timestamp]
  }

  my @db_choices = map {
    my @dbs = map [$_,opt($_)], grep $_->file_modtime, $_->blast_dbs( web_interface_visible => 't');
    @dbs ? ('__'.$_->name, @dbs) : ()
  } CXGN::BlastDB::Group->search_like(name => '%',{order_by => 'ordinal, name'});

  my @ungrouped_dbs = grep $_->file_modtime,CXGN::BlastDB->search( blast_db_group_id => undef, web_interface_visible => 't', {order_by => 'title'} );
  if(@ungrouped_dbs) {
    push @db_choices, '__Other',  map [$_,opt($_)], @ungrouped_dbs;
  }

  @db_choices or return '<span class="ghosted">The BLAST service is temporarily unavailable, we apologize for the inconvenience</span>';

  my $selected_db_file_base = $prefs->get_pref('last_blast_db_file_base');
  #warn "got pref last_blast_db_file_base '$selected_db_file_base'\n";

  my %prog_descs = ( blastn  => 'BLASTN (nucleotide to nucleotide)',
		     blastx  => 'BLASTX (nucleotide to protein; query translated to protein)',
		     blastp  => 'BLASTP (protein to protein)',
		     tblastx => 'TBLASTX (protein to protein; both database and query are translated)',
		     tblastn => 'TBLASTN (protein to nucleotide; database translated to protein)',
		   );

  my @program_choices = map {
    my ($db) = @$_;
    if($db->type eq 'protein') {
      [map [$_,$prog_descs{$_}], 'blastx','blastp']
    } else {
      [map [$_,$prog_descs{$_}], 'blastn','tblastx','tblastn']
    }
  } grep ref, @db_choices;

  @db_choices = map {ref($_) ? $_->[1] : $_} @db_choices;

  return hierarchical_selectboxes_html( parentsel => { name => 'database',
						       choices =>
						       \@db_choices,
						       $selected_db_file_base ? (selected => $selected_db_file_base) : (),
						     },
					childsel  => { name => 'program',
						     },
					childchoices => \@program_choices
				      );
}
