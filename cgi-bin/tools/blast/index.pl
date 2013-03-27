use CatalystX::GlobalContext qw( $c );

=head1 NAME

/tools/blast/ - the entry page to the SGN blast tool

=head1 DESCRIPTION

This page displays a text box for a query sequence, along with a
number of pull down menus to select (1) the dataset to match against,
(2) the blast program, (3) an evalue cutoff, (4) a substitution
matrix, (5) the number of maximum hits to show, and (6) parameters
affecting the output of the results.

Important features: the default dataset selected is
tomato_combined. If the user selects another dataset, this is stored
in the user prefs and comes up as the default later on. A specific
dataset can be pre-selected in a link using the db_id parameter.

This script is in desparate need of a decent re-factoring...

Parameters:

=over 5

=item preload_id

an id that can be preloaded from the database. Requires preload_type
to be set as well.

=item preload_type

the type of identifier to preload from the database (7 is EST, 15 is
unigene). Requires preload_id to be set as well.

=item seq

a sequence to blast, automatically filled in

=item interface_type

either 'simple' or 'advanced', affects the features displayed on the
page.

=item db_id

an id of a database, which will appear pre-selected in the pulldown
menu.

=back

=head1 AUTHORS

This script was initially written by Koni Wright. Many additions and
changes by SGN staff. POD by Lukas.

=cut


use Modern::Perl;
use POSIX;
use English;

use Memoize;
use Storable qw/ retrieve nstore /;

use Tie::UrlEncoder;
our %urlencode;

use File::Flock;

use CXGN::Page;
use CXGN::BlastDB;
use CXGN::Page::FormattingHelpers qw/page_title_html modesel info_table_html hierarchical_selectboxes_html simple_selectbox_html/;
use CXGN::Page::UserPrefs;
use CXGN::Tools::List qw/evens distinct/;
use CatalystX::GlobalContext '$c';

my $page  = CXGN::Page->new("BLAST Search Interface","Evan");
my $dbh   = CXGN::DB::Connection->new;
my $prefs = CXGN::Page::UserPrefs->new( $dbh );

my %params;
{ my @p = qw/preload_id preload_type seq interface_type db_id flush_cache/;
  @params{@p} = $page->get_encoded_arguments(@p);
}

$params{interface_type} ||= 0;

my $blast_path = $c->config->{'blast_path'};
my $blast_version = do {
  unless( -x "$blast_path/blastall") {
    ''
  } else {
    eval {
      open BP, qq{echo '>shutup' | $blast_path/blastall -p blastn 2>&1 |};
      my $v = '';
      while (<BP>) {
	if (m/BLASTN (.+)/) {
	  $v = " v. $1";
	  last;
	}
      }
      close BP;
    }; if( $EVAL_ERROR ) {
      ''
    }
  }
};

my $preload_seq;
if ($params{preload_type}) {
  if ($params{preload_type} == 7) {

    my $estq = $dbh->prepare_cached(<<EOSQL);
SELECT COALESCE( CASE WHEN hqi_length > 0 THEN SUBSTRING(seq, hqi_start::integer+1, hqi_length::integer)
                      ELSE NULL
                 END,
                 seq
               )
FROM est
LEFT JOIN qc_report USING (est_id)
WHERE est.est_id=?
EOSQL

    $estq->execute($params{preload_id});

    if ($estq->rows == 0) {
      die("Preloaded BLAST search specified EST sequence SGN-E$params{preload_id} but it is not found in database ($params{preload_id})");
    }

    ($preload_seq) = $estq->fetchrow_array();

    my $x = "";
    my $i = 0;
    while((length($preload_seq) - $i) > 78) {
      $x .= substr($preload_seq, $i, 78) . "\n";
      $i+=78;
    }
    $x .= substr($preload_seq, $i) . "\n";
    $preload_seq = ">SGN-E$params{preload_id}\n$x\n";

  } elsif ($params{preload_type} == 15) {

    my $memberq = $dbh->prepare_cached("SELECT nr_members FROM unigene WHERE unigene_id=?");
    $memberq->execute($params{preload_id});
    if ($memberq->rows == 0) {
      $page->error_page("Preloaded BLAST search specified unigene identifier ($params{preload_id}) which is not found");
    }

    my ($nr_members) = $memberq->fetchrow_array();
    if ($nr_members > 1) { 
      ($preload_seq) = $dbh->selectrow_array(<<EOSQL,undef,$params{preload_id})
SELECT seq
FROM unigene
INNER JOIN unigene_consensi
USING (consensi_id)
WHERE unigene_id=?
EOSQL
    } else {
      ($preload_seq) = $dbh->selectrow_array(<<EOSQL,undef,$params{preload_id});
SELECT COALESCE( CASE WHEN hqi_length > 0
                           THEN SUBSTRING(seq, hqi_start::integer+1, hqi_length::integer)
                      ELSE NULL
                 END,
                 seq
               )
FROM unigene
LEFT JOIN unigene_member USING (unigene_id)
LEFT JOIN est USING (est_id)
LEFT JOIN qc_report USING (est_id)
WHERE unigene.unigene_id=?
EOSQL
    }
    my $x = "";
    my $i = 0;
    while((length($preload_seq) - $i) > 78) {
      $x .= substr($preload_seq, $i, 78) . "\n";
      $i+=78;
    }
    $x .= substr($preload_seq, $i) . "\n";
    $preload_seq = ">SGN-U$params{preload_id}\n$x";
  } else {
    $page->error_page("Unknown preloaded sequence type\n");
  }
} elsif ($params{seq}) {
  $preload_seq = $params{seq};
} else {
  $preload_seq = "";
}

$page->header('SGN BLAST');
$page->jsan_use('jquery');

my ($databases,$programs,$programs_js) = blast_db_prog_selects( $params{db_id}, $params{flush_cache}, $prefs );
my $spellcheck_js = <<'';
// turn off spell check on sequence inputs without emitting invalid HTML
jQuery(function($) { $('#sequence_input').attr('spellcheck',false) });


sub hash2param {
  my %args = @_;
  no warnings 'uninitialized';
  return join '&', map "$urlencode{$_}=$urlencode{$args{$_}}", distinct evens @_;
}

print page_title_html("NCBI BLAST$blast_version");
print modesel([ ['?'.hash2param(%params, interface_type => 0),'Simple'],
		['?'.hash2param(%params, interface_type => 1),'Advanced'],
	      ],
	      $params{interface_type},
	     );

#simple blast interface form
if($params{interface_type} == 0) {
  print <<EOF

<script language="JavaScript" type="text/JavaScript" >

function clearField() {
    // OK - there are three ways to clear the fields.
    // The first is let the browser do it. Then it does not clear
    // with preset sequences. The second way is to clear it with javascript.
    // on reload, this will create confusion with preset sequences.
    // The third way is simply to redirect to the empty page. Thats good
    // because it also resets to the users preferred datatset.
    // var i = document.getElementById("sequence_input");
    // i.innerHTML='';
    window.location="index.pl";
}

</script>

<form method="post" action="blast_result.pl" name="blastform">
  <input type="hidden" checked="checked" name="filterq" value="1" />
  <input type="hidden" name="interface_type" value="simple" />
  <input type="hidden" name="outformat" value="0" />
  <table align="center" summary="" cellpadding="0" cellspacing="15">
    <tr><td><b>Sequence Set</b> </td><td>$databases <a style="font-size: 80%" title="View details of each database" href="dbinfo.pl">db details</a></td></tr>
    <tr><td><b>Program</b> </td><td>$programs</td></tr>
    <tr><td colspan="2" align="center"><b>Query sequence</b><div style="font-size: 80%">single sequence only, use Advanced for multiple</div><textarea name="sequence" id="sequence_input" rows="8" cols="80">$preload_seq</textarea></td></tr>
    <tr><td colspan="2">
      <table width="100%"><tr>
         <td>
EOF
  .info_table_html('Expect (e-value) Threshold' => '<input type="text" size="6" value="1e-10" name="expect" />',
		   'Substitution Matrix' => simple_selectbox_html( name => 'matrix',
								    choices => [ [ 'BLOSUM62', 'BLOSUM62 (default)' ],
										 [ 'BLOSUM80', 'BLOSUM80 (recent divergence)' ],
										 [ 'BLOSUM45', 'BLOSUM45 (ancient divergence)' ],
										 'PAM30',
										 'PAM70',
									       ],
								  ),
		    'Max. hits to show' => '<input type="text" name="maxhits" size="6" value="100" />',
		   ' ' => '<div style="text-align: right"><input type="reset" value="Clear" onclick="clearField(); "/> <input type="submit" name="search" value="Search" /></div>',
		    'Show Graphics' => simple_selectbox_html( name => 'output_graphs',
							      choices => [ [ 'bioperl_histogram', 'all' ],
									   'none',
									   [ 'bioperl_only', 'alignment summary only' ],
									   [ 'histogram_only', 'conservedness histogram only' ],
									 ],
							    ),
		    __multicol => 2,
		    __border => 0,
		    __tableattrs => 'width="100%"',
		  )
    .<<EOF
         </td>
      </tr>
      </table>
    </td></tr>
  </table>
</form>
<script language="JavaScript" type="text/javascript">
$programs_js
$spellcheck_js
</script>
EOF
      ;
}

#advanced blast interface form
else {
  my $mselect = simple_selectbox_html( name => 'outformat',
				       choices => [ [0  => '0 - pairwise (default)'],
						    [1  => '1 - query-anchored showing identities'],
						    [2  => '2 - query-anchored no identities'],
						    [3  => '3 - flat query-anchored, show identities'],
						    [4  => '4 - flat query-anchored, no identities'],
						    [5  => '5 - query-anchored no identities and blunt ends'],
						    [6  => '6 - flat query-anchored, no identities and blunt ends'],
						    [7  => '7 - XML Blast output'],
						    [8  => '8 - tabular'],
						    [9  => '9 - tabular with comment lines'],
						    [10 => '10 - ASN, text'],
						    [11 => '11 - ASN, binary'],
						  ],
				     );

  print <<EOF;
<table style="border: 1px solid gray; padding: 1em 2em 1em 2em; background: #eeeeff;"><tr><td><img src="/documents/img/info_icon.png" border="0" style="margin-right: 1em; vertical-align: middle" /></td><td style="padding-top: 0.35em">This version of the BLAST online tool allows multiple query sequences, more control over running options, and more report formats.</td></tr></table>
<form method="post" action="blast_result.pl" name="blastform" enctype="multipart/form-data">
  <input type="hidden" name="interface_type" value="advanced" />
  <table id="blastinput" align="center" summary="" cellpadding="0" cellspacing="15">
    <tr><td><b>Database (<tt>-d</tt>)</b> </td><td>$databases <a style="font-size: 80%" title="View details of each database" href="dbinfo.pl">db details</a></td></tr>
    <tr><td><b>Program (<tt>-p</tt>)</b> </td><td>$programs</td></tr>
    <tr>
      <td><b>Query sequences (<tt>-i</tt>)</b></td>
      <td >
        <textarea class="fix" id="sequence_input" name="sequence" rows="8" cols="65">$preload_seq</textarea><br />
        <b>AND/OR upload multi-fasta query file</b> <input type="file" name="file" />
      </td>
    </tr>
    <tr><td><b>Output format (<tt>-m</tt>)</b></td>
        <td>$mselect</td>
    </tr>
    <tr><td><b>Substitution Matrix (<tt>-M</tt>)</b></td>
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
    <tr><td><b>Expectation value (<tt>-e</tt>)</b> </td>
        <td ><input type="text" size="6" value="1e-10" name="expect" /></td>
    </tr>
    <tr><td><b>Max DB seqs to show hits from (<tt>-b</tt>)</b></td>
        <td ><input type="text" name="maxhits" size="6" value="100" /></td>
    </tr>
    <tr><td><b>Filter query sequence (DUST with blastn, SEG with others) (<tt>-F</tt>)</b></td>
        <td><input type="checkbox" checked="checked" name="filterq" /></td>
    </tr>
    <tr>
    	<td>
    		<b>Show Graphics</b><br /><span style="font-size: 80%">not available for multiple query seqs</span>
    	</td>
    	<td>
    		<select name="output_graphs">
    			<option value="none">none</option>
    			<option value="bioperl_only">alignment summary only</option>
    			<option value="histogram_only">conservedness histogram only</option>
    			<option value="bioperl_histogram" selected="selected">all</option>
    		</select>
    	</td>
    </tr>

    <tr><td align="right"><input type="reset" value="Clear" /></td><td align="center"><input type="submit" name="search" value="Submit" style="background: red; font-size: 130%" /></td></tr>
     </table>
</form>
<script language="JavaScript" type="text/javascript">
$programs_js
$spellcheck_js
</script>
EOF

}

$page->footer();

##########################################################################################################################

memoize '_cached_file_modtime';
sub _cached_file_modtime {
  shift->file_modtime
}

sub blast_db_prog_selects {
    my ( $db_id, $flush_cache, $prefs ) = @_;

    my $db_choices = blast_db_choices( $flush_cache );

    return '<span class="ghosted">The BLAST service is temporarily unavailable, we apologize for the inconvenience</span>'
        unless @$db_choices;

    # DB select box will either the db_id supplied, or what the user last selected, or the tomato combined blast db
    my $selected_db_id = $db_id || $prefs->get_pref('last_blast_db_id')
	|| do {
	    my ($d) = map $_->blast_db_id,
                      grep _cached_file_modtime($_),
                      grep $_->web_interface_visible,
                      CXGN::BlastDB->search_ilike( title => '%SGN Tomato Combined%' );
            $d;
        };

    my %prog_descs = ( blastn  => 'BLASTN (nucleotide to nucleotide)',
                       blastx  => 'BLASTX (nucleotide to protein; query translated to protein)',
                       blastp  => 'BLASTP (protein to protein)',
                       tblastx => 'TBLASTX (protein to protein; both database and query are translated)',
                       tblastn => 'TBLASTN (protein to nucleotide; database translated to protein)',
                      );

    my @program_choices = map {
        my ($db) = @$_;
        if ($db->type eq 'protein') {
            [map [$_,$prog_descs{$_}], 'blastx','blastp']
        } else {
            [map [$_,$prog_descs{$_}], 'blastn','tblastx','tblastn']
        }
    } grep ref, @$db_choices;

    @$db_choices = map {ref($_) ? $_->[1] : $_} @$db_choices;

    return hierarchical_selectboxes_html( parentsel => { name => 'database',
                                                         choices => $db_choices,
                                                         ( $selected_db_id ? (selected => $selected_db_id) : () ),
						       },
                                          childsel  => { name => 'program' },
                                          childchoices => \@program_choices
                                         );
}

sub blast_db_choices {
    my ( $flush_cache ) = @_;

    my $choices_cache_filename = $c->path_to( $c->generated_file_uri('blast','choices_cache.dat') );
    my $lockfile = "$choices_cache_filename.lock";

    unless( $flush_cache ) {
        my $l = File::Flock->new($lockfile,'shared');
        my $cache_modtime = (stat($choices_cache_filename))[9];

        if( $cache_modtime && $cache_modtime > time - 15*60 ) {
            my $data = retrieve( $choices_cache_filename );
            return $data if $data;
        }
    }

    my $l = File::Flock->new($lockfile);
    my $choices = _build_blast_db_choices();
    nstore( $choices, $choices_cache_filename )
        or warn "WARNING: $! caching blast db choices in file '$choices_cache_filename'";
    return $choices;
}

sub _build_blast_db_choices {

    sleep 5;

    my @db_choices = map {
        my @dbs = map [ $_, bdb_opt($_) ],
            grep _cached_file_modtime($_), #filter for dbs that are on disk
                $_->blast_dbs( web_interface_visible => 't'); #get all dbs in this group
        @dbs ? ('__'.$_->name, @dbs) : ()
    } CXGN::BlastDB::Group->search_like(name => '%',{order_by => 'ordinal, name'});

    my @ungrouped_dbs =
        grep _cached_file_modtime($_),
        CXGN::BlastDB->search(
            blast_db_group_id => undef,
            web_interface_visible => 't',
            { order_by => 'title' }
           );

    push @db_choices, ( '__Other',
                        map [$_,bdb_opt($_)],
                        @ungrouped_dbs
                       );

    return \@db_choices;
}

sub bdb_opt {
    my $db = shift;
#     my $timestamp = _cached_file_modtime($db)
#         or return;
#     $timestamp = strftime(' &nbsp;(%F)',gmtime _cached_file_modtime($db));
    my $seq_count = $db->sequences_count;
	
    [$db->blast_db_id, $db->title ]
}
