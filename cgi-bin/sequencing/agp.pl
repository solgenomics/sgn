use strict;

use File::Temp qw//;
use File::Spec;

use Bio::DB::GenBank;

use CXGN::TomatoGenome::BACPublish qw/tpf_agp_files/;
use CXGN::BioTools::AGP qw/agp_parse agp_write/;
use CXGN::Genomic::Clone;
use CXGN::Genomic::CloneIdentifiers qw/parse_clone_ident/;
#use CXGN::Login; # does not seem to be used
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      page_title_html
				      columnar_table_html
				      info_table_html
				      modesel
				      html_break_string
				    );
use CXGN::People;
use CXGN::Publish qw/publish/;
use CXGN::Tools::List qw/str_in/;


#tpf_agp is in the current directory
use CXGN::TomatoGenome::tpf_agp qw(
				   format_validation_report
				   filename
				   published_ftp_download_links
				   tabdelim_to_html
				   tabdelim_to_array
				   modtime_string
				  );

my $page = CXGN::Page->new("AGP Display","Rob");

#get input arguments and validate
my ($chr) = $page->get_arguments(qw/chr/);
$chr += 0; #force chr to be numeric
$chr ||= 1;

#if we have a file upload, validate it according to its type and store it
if(my $upload = $page->get_upload ) {
  #get the active login
#   my $sp_person_id = CXGN::Login->new()->verify_session()
#     or $page->error_page("Login ID not found");
#   my $sp = CXGN::People::Person->new($sp_person_id);
#   $sp->get_username
#     or $page->error_page("Username not found.","","", "Username not found for sp_person_id '$sp_person_id'");

#   #check that the login has permission to upload for this chromosome
#   unless($sp->get_user_type eq 'curator'
# 	 || grep {$_ == $chr && $_ <= 12 && $_ >= 1} $sp->get_projects_associated_with_person) {
#     $page->error_page('your account does not have privileges to upload files for that chromosome');
#   }

  my $validation_report = validate_and_publish_agp($upload->fh,$chr);
  $page->message_page('AGP validation failed',$validation_report) if $validation_report;
}


$page->header('Assembly Display',"Chromosome Assemblies");
print <<EOHTML;
<p>The listings below have been developed and submitted to SGN by the individual <a href="/about/tomato_sequencing.pl">tomato chromosome sequencing projects</a>.</p>
<p>The AGP file describes the current best known sequence assembly of this chromosome.  Descriptions of this file format are available <a href="http://www.ncbi.nlm.nih.gov/genome/guide/Assembly/AGP_Specification.html">from NCBI</a> and <a href="http://genome.ucsc.edu/goldenPath/datorg.html">from UCSC</a>.</p>
<p>These files are also available for download <a href="ftp://ftp.sgn.cornell.edu/tomato_genome/agp">via FTP</a>.</p>
EOHTML

print qq|<div style="text-align: center; font-weight: bold; margin-bottom: 0.5em">Chromosome</div>\n|;
print modesel( [map {["?chr=$_",$_]} 1..12], $chr-1);
print "<br />\n";

#now show the current tpf and agp files
my (undef,$published_agp) = tpf_agp_files($chr);
my $agp_modtime  = modtime_string($published_agp);
my (undef,$published_agp_ftp) = published_ftp_download_links($chr);
print info_section_html( title    => 'Accessioned Golden Path (AGP)',
			 subtitle => "$agp_modtime  $published_agp_ftp",
			 contents => agp_to_html($published_agp) || <<EOHTML,
<center><b>No AGP file is currently available for chromosome $chr</b></center>
EOHTML
		       );
print info_section_html( title    => "Other Chromosome $chr Resources",
			 contents =>  <<EOHTML,
<ul>
<li>Tomato maps: <a href="/cview/index.pl">Genetic</a> | <a href="/cview/map.pl?map_id=9&amp;physical=1">Physical</a> | <a href="/cview/map.pl?map_id=13">BAC FISH results</a></li>
<li><a href="/tomato/genome_data.pl?chr=$chr">Chromosome $chr BACs in Genome Browser</a></li>
<li><a href="tpf.pl?chr=$chr">Chromosome $chr Tiling Path (TPF)</a></li>
</ul>
EOHTML
		       );
$page->footer;


sub validate_and_publish_agp {
  my ($agp_fh,$chr) = @_;

  #warn "we got a '$agp_fh', which refs to ".ref($agp_fh);

  #parse the AGP, validate its syntax
  my @errors;
  my $lines = agp_parse($agp_fh, validate_syntax => 1, error_array => \@errors )
    or return format_validation_report(@errors);

  #now check the report for consistency in other things
  my $err = sub {
    my $linerec = shift;
    push @errors, "<AGP>:$linerec->{linenum}: ".shift;
  };

  foreach our $l (@$lines) {
    next if $l->{comment}; #ignore comments for this step

    my $err = sub {
      push @errors, "<AGP>:$l->{linenum}: ".shift;
    };

    #check that we have the correct object identifier
    $l->{objname} eq "S.lycopersicum-chr$chr"
      or $err->("first column must be 'S.lycopersicum-chr$chr', not '$l->{objname}'");

    if(my $ident = $l->{ident}) {
      	my $p = parse_clone_ident($ident,'agi_bac_with_chrom','agi_bac','versioned_bac_seq');

	#try to treat it as a versioned genbank accession.  look it
	#up, get its clone name, then compare its sequence to the most
	#recent sequence we have on file for that clone.  error if
	#they don't match
	my $c = $p ? CXGN::Genomic::Clone->retrieve_from_parsed_name($p)
	             || $err->("Unknown sequence identifier '$ident'")
	           : lookup_and_match_genbank_accession($ident,$err);

	unless( ref $c ) {
	  $err->("Cannot find a BAC sequence for identifier '$ident'");
	} else {
	  $c->chromosome_num == $chr
	    or $err->("BAC referenced in identifier '$ident' is not currently assigned to chromosome $chr");
	  my $latest_ver = $c->latest_sequence_version;
	  !$p->{version} || $p->{version} == $latest_ver
	    or $err->("The sequence version for '$ident' differs from the latest sequence version in the SGN database, which is '$latest_ver'.");

	  #rewrite the identifier to the SGN-type identifier
	  $l->{ident} = $c->latest_sequence_name
	    or $err->("The sequence for '$ident' has not yet been loaded into the SGN database.  If you have not yet submitted it, please do so before publishing this assembly.  If you have already submitted it, please wait a few hours to ensure the loading is completed, then try uploading this file again.");

	  # check that the length of this element is not longer than the element referred to
	  my $seq = $c->seq
	    or $err->("Could not fetch seq for '$ident'");
	  my $seqlen = length($seq);
	  $seqlen >= $l->{length}
	    or $err->("length of this component ($l->{length} bases) is too large to be covered by the sequence specified ($ident, $seqlen bases)");
	}
    }

  }

  #splat if we have errors
  @errors
    and return format_validation_report(@errors);

  #otherwise, go ahead and rewrite and publish
  my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.agp' );
  agp_write($lines,$tmp);
  close $tmp;

  my $publishing_filename = filename($chr,'agp')
    or die "no filename to publish to??";
  publish(['cp', "$tmp", $publishing_filename]);

  return;
}

sub agp_to_html {
  my ($filename) = @_;
  if( $filename && -f $filename ) {
    return tabdelim_to_html($filename, 'AGP',
			    sub {
			      my ($contents) = @_;
			      if ($contents =~ /^#/) {
				'color: green'
			      } # elsif ( $contents eq 'N' ) {
# 				''
# 			      } elsif( $contents eq 'yes' ){
# 				'color: green; font-weight: bold'
# 			      } elsif( $contents eq 'F' ) {
# 				'background: #b0b0e4; font-weight: bold;'
# 			      } elsif( $contents eq 'D' ) {
# 				'background: #bfbfbf'
# 			      } elsif( $contents eq 'contig' ) {
# 				'color: gray'
# 			      }
			    }
			   );
  }
}

#lookup the given string as a versioned genbank accession, return the
#clone object if you can find it in genbank, and it has the same
#sequence as the latest sequence we have on file for that bac
sub lookup_and_match_genbank_accession {
  my ($accession,$err) = @_;

  unless($accession =~ /^[a-z]{2}\d+\.\d+$/i) {
    $err->("Unknown identifier '$accession'");
    return;
  }

  my $gb = Bio::DB::GenBank->new;
  my $seq = eval{$gb->get_Seq_by_version($accession)}; #this dies if the acc doesn't exist
  warn $@ if $@;
  unless($seq) {
    $err->("'$accession' looks like it might be a GenBank accession, but is not found in GenBank.");
    return;
  }

  #find the word in the description line that is our clone identifier
  my $clone;
  foreach my $word (split /\s+/,$seq->desc) {
    if( my $p = parse_clone_ident($word,'agi_bac_with_chrom','agi_bac') ) {
      $p->{match} = $accession;
      $clone = CXGN::Genomic::Clone->retrieve_from_parsed_name($p);
      last;
    }
  }
  unless($clone) {
    $err->("Could not match GenBank accession '$accession' to a clone name.  Is a clone name included in the DEFINITION field for that record?");
    return;
  }

  unless($clone->latest_sequence_name) {
    $err->("GenBank record for $accession purports to be for SGN BAC identifier ".$clone->clone_name_with_chromosome.", but no sequence has been submitted to SGN for this clone.  Please upload it to SGN.");
    return;
  }

  #now make sure the clones have the same sequence
  my @clone_seqs = $clone->seq;
#  warn "checking our seq ".length($clone_seqs[0])." against their seq ".length($seq->seq);
  unless(@clone_seqs == 1 && compare_gb_and_sgn_seqs($seq->seq,$clone_seqs[0])) {
    $err->("Sequence in GenBank for $accession does not match SGN sequence for ".$clone->latest_sequence_name.".  Please update either SGN or GenBank such that they match, or use SGN versioned sequence identifiers (e.g. C01HBa0001A01.1).");
#    warn "seq for $accession is\n".$clone_seqs[0]
  }

  #if we get here, it all miraculously matched up
  return $clone;
}


#compare a genbank and an sgn sequence, allowing for X-masked
#nucleotides that may be present in the sgn sequence
sub compare_gb_and_sgn_seqs {
  my ($gb_seq,$sgn_seq) = @_;

  #easy if they're straight equal
  return 1 if $gb_seq eq $sgn_seq;

  #otherwise, do a match taking into account the X's in the SGN sequence

  return 0 unless
    length($gb_seq) == length($sgn_seq)
      && $sgn_seq =~ /[Xx]/;

  $gb_seq = lc $gb_seq;
  $sgn_seq = lc $sgn_seq;

  for(my $i=0;$i<length($gb_seq);$i++) {
    my $gb = substr($gb_seq,$i,1);
    my $sgn = substr($sgn_seq,$i,1);
    if($gb ne $sgn && $sgn ne 'x') {
      return 0;
    }
  }
  return 1;
}
