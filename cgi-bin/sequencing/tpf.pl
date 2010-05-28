
use strict;

use File::Temp qw//;
use File::Spec;

use CXGN::DB::Connection;
use CXGN::TomatoGenome::BACPublish qw/tpf_agp_files/;
use CXGN::Genomic::Clone;
use CXGN::Genomic::CloneIdentifiers qw/parse_clone_ident/;
use CXGN::Login;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw( info_section_html
				      page_title_html
				      columnar_table_html
				      info_table_html
				      modesel
				    );
use CXGN::People;
use CXGN::Publish qw/publish/;

#tpf_agp is in the current directory
use CXGN::TomatoGenome::tpf_agp qw(
				   format_validation_report
				   filename
				   published_ftp_download_links
				   tabdelim_to_html
				   tabdelim_to_array
				   modtime_string
				  );
use CXGN::VHost;

my $page = CXGN::Page->new("Tiling Path Display","Rob");
my $dbh = CXGN::DB::Connection->new();

#get input arguments and validate
my ($chr) = $page->get_arguments(qw/chr/);
$chr += 0; #force chr to be numeric
$chr ||= 1;

#if we have a file upload, validate it according to its type and store it
if(my $upload = $page->get_upload ) {
  #get the active login
  my $sp_person_id = CXGN::Login->new($dbh)->verify_session();
  my $sp = CXGN::People::Person->new($dbh, $sp_person_id);
  $sp->get_username
    or do {print $page->header; graceful_exit("Username not found.")};

  #check that the login has permission to upload for this chromosome
  unless($sp->get_user_type eq 'curator'
	 || grep {$_ == $chr && $_ <= 12 && $_ >= 1} $sp->get_projects_associated_with_person) {
    print $page->header(); graceful_exit('your account does not have privileges to upload files for that chromosome');
  }

  my $validation_report = validate_and_publish_tpf($upload->fh,$chr);
  $page->message_page('TPF validation failed',$validation_report) if $validation_report;
}


$page->header('TPF Display',"Chromosome Tiling Paths");
print <<EOHTML;
<p>The tiling path listings below have been developed and submitted to
SGN by the individual <a href="/about/tomato_sequencing.pl">tomato
chromosome sequencing projects</a>.</p>

<p>The listing below shows the clones that make up the current planned
tiling path for this chromosome, along with any gaps that have yet
to be bridged by a sequence of clones.</p>

<p>It is in TPF format, which consists of three columns:</p>
<ol>
  <li>the NCBI/EMBL Accession of the BAC sequence</li>
  <li>the SGN name of the BAC sequence</li>
  <li>a name for each contiguous group of BACs, internal to each chromosome sequencing project</li>
</ol>

<p>These files are also available for download <a href="ftp://ftp.sgn.cornell.edu/tomato_genome/tpf">via FTP</a>.</p>
EOHTML

if ($chr > 12 or $chr < 1){
  graceful_exit("Oops! Chromosome number must be between 1-12.");
}

print qq|<div style="text-align: center; font-weight: bold; margin-bottom: 0.5em">Chromosome</div>\n|;
print modesel( [map {["?chr=$_",$_]} 1..12], $chr-1);
print "<br />\n";


#now show the current tpf and agp files

my $published_tpf;
eval {
  ($published_tpf,undef) = tpf_agp_files($chr);
};
if ($@){
  graceful_exit($@);
}

my ($published_tpf_ftp,undef) = published_ftp_download_links($chr);
print info_section_html( title    => 'Tiling Path Format (TPF)',
			 subtitle => modtime_string($published_tpf).'  '.$published_tpf_ftp,
			 contents => tpf_to_html($published_tpf) || <<EOHTML,
<center><b>No TPF file is currently available for chromosome $chr</b></center>
EOHTML
		       );
print info_section_html( title    => "Other Chromosome $chr Resources",
			 contents =>  <<EOHTML,
<ul>
<li>Tomato maps: <a href="/cview/index.pl">Genetic</a> | <a href="/cview/map.pl?map_id=9&amp;physical=1">Physical</a> | <a href="/cview/map.pl?map_id=13">BAC FISH results</a></li>
<li><a href="/tomato/genome_data.pl?chr=$chr">Chromosome $chr BACs in Genome Browser</a></li>
<li><a href="agp.pl?chr=$chr">Chromosome $chr Assembly (AGP)</a></li>
</ul>
EOHTML
		       );
$page->footer;



# we should NOT be using error_page! Use this instead!
sub graceful_exit {

  my ($message) = @_;
  print $message;
  print $page->footer;
  exit;

}

#CHECK:
#correct number of columns
#correct data type of each column
#correctly formed bac identifiers
#bac identifiers are on the correct chromosome
sub validate_and_publish_tpf {
  my ($tpf_fh,$chr) = @_;
  my $publishing_filename = filename($chr,'tpf');
  my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.tpf' );
  my @errors;
  my $line_ctr = 0;
  my $err = sub {
    push @errors, "Line $line_ctr: ".shift;
  };
  #copy the tpf file from the apache-spooled temp file.  while doing
  #that, go over each line and validate it
  while(my $line = <$tpf_fh>) {
    $line_ctr++;
    chomp $line;
    $line =~ s/\r$//;
    unless($line =~ /^\s*#/) {
      my @d = split /\s+/,$line;
      @d == 3 or $err->("Incorrect column count:  ".scalar(@d)." columns found");
      if( $d[0] =~ /^GAP$/ ) {
	$d[1] =~ /^type-[1234]$|/ or $err->("If first column is GAP, second column must be a type-[1234] gap type");
	$d[2] eq '?' or $err->("If first column is 'GAP', third column must be '?' (it is '$d[2]')");
      }
      elsif( $d[0] eq '?' || $d[0] =~ /^\S{5,}$/ ) {
	my $p = parse_clone_ident($d[1],qw/agi_bac_with_chrom agi_bac/)
	    or $err->("If line is not a gap, second column must be a valid SGN BAC clone identifier");
	if($p) {
	  my $c = CXGN::Genomic::Clone->retrieve_from_parsed_name($p)
	    or $err->("Unknown clone identifier '$d[1]' in second column");
	  if($c) {
	    $c->chromosome_num == $chr
	      or $err->("BAC with identifier '$d[1]' is not registered as being on chromosome $chr");
	    $d[1] = $c->clone_name_with_chromosome;
	  }
	}
      }
      else {
	$err->("Invalid first column '$d[0]'");
      }
      print $tmp join("\t",@d)."\n";
    } else {
      print $tmp "$line\n";
    }
  }
  close $tmp; #make sure we flush the writes we made
  if(@errors) {
    return format_validation_report(@errors);
  } else {
    publish(['cp', "$tmp", $publishing_filename]);
    return;
  }
}

sub tpf_to_html {
  my ($filename) = @_;
  if($filename && -f $filename) {
    return tabdelim_to_html($filename,undef,
			#this sub looks at the contents of each
			#table cell and might emit some style rules
			#to highlight it
			    sub {
			      my ($contents) = @_;
			      if ($contents =~ /^\s*#/) {
				'color: green'
			      } elsif ( $contents =~ /^\s*GAP\s*$/ ) {
				'color: red'
			      } elsif ( $contents =~ /^\s*\?\s*$/ ) {
				'font-weight: bold'
			      }
			    }
			   );

  }
}

