use strict;
use warnings;

use Carp;
use FindBin;
use Getopt::Std;

use File::Find;
use File::Basename;

use CXGN::DB::Connection;

use CXGN::Metadata;
use CXGN::Genomic::CloneIdentifiers qw/parse_clone_ident/;
use CXGN::Genomic::Clone;
use CXGN::Genomic::Search::Clone;
use CXGN::Tools::Identifiers qw/link_identifier/;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/columnar_table_html/;
use CatalystX::GlobalContext qw( $c );

my $page = CXGN::Page->new('BAC Registry <-> FTP Discrepancies','Robert Buels');

$page->header('BAC Registry <-> FTP Discrepancies','BAC Registry <-> FTP Discrepancies');

my $ftp_path = $c->config->{'ftpsite_root'};

if(-d $ftp_path ) {
  my %sequenced_bacs = map {
    my ($bacname,$dirname) = fileparse($_,qr|\..+$|)
      or return;
    my $parsed = parse_clone_ident($bacname,'agi_bac_with_chrom')
      or return;
    #        $parsed->{match} eq $bacname
    # 	 or return;
    $parsed->{dirname} = $dirname;

    #return
    ($bacname => $parsed)
  } glob(File::Spec->catfile($ftp_path,'tomato_genome','bacs','chr*','*finished','*.tar.gz'));

  my @discrepancies;
  my @sequenced_bac_names = sort keys %sequenced_bacs;

  foreach my $bacname (@sequenced_bac_names) {
    my $clone = CXGN::Genomic::Clone->retrieve_from_parsed_name($sequenced_bacs{$bacname})
      or die "Could not retrieve clone $bacname\n";
    $sequenced_bacs{$bacname}->{clone_object} = $clone;
    my $dirname = $sequenced_bacs{$bacname}->{dirname};
    my $truestatus = $dirname =~ m|unfinished| ? 'in_progress' : 'complete';
    my ($chr_from_dir) = $dirname =~ /chr(\d{2})/;
    $chr_from_dir += 0;		#make sure it's numeric
    $sequenced_bacs{$bacname}->{true_status} = $truestatus;
    unless( $clone->sequencing_status eq $truestatus ) {
      push @discrepancies,
	[
#	 $clone->clone_id,
	  $clone->chromosome_num || $chr_from_dir,
	  link_identifier($clone->clone_name_with_chromosome || $clone->clone_name,'bac'),
	  $truestatus,
	  $clone->sequencing_status,
#	  $dirname,
	];
    }
    #   else {
    #     print "actually right!\n";
    #   }
  }

  #now find all the BACs that are marked complete in the database and aren't
  #found on the filesystem
  my $search = CXGN::Genomic::Search::Clone->new;
  my $query = $search->new_query;
  $query->sequencing_status('=?','complete');
  my $results = $search->do_search($query);
  $results->autopage($query,$search);
  while (my $clone = $results->next_result) {
    my $chrname = $clone->clone_name_with_chromosome;
    #  print $clone->clone_name." = $chrname\n";
    unless ( my $record = $sequenced_bacs{$chrname} ) {
      push @discrepancies,
	[
#	 $clone->clone_id,
	 $clone->chromosome_num || '',
	 link_identifier($chrname,'bac'),
	 'not present',
	 $clone->sequencing_status,
#	 '',
	];
    }
    #   else {
    #     print "actually right!\n"
    #   }
  }

  print( '<center>',
	 columnar_table_html( headings => ['Chr','Name','On FTP','In Database'],
			      data     => [sort {$a->[0] <=> $b->[0]
						 || $a->[1] cmp $b->[1]
					       } @discrepancies
					  ],
			      __tableattrs => 'width="50%" cellspacing="0"',
			    ),
	 '</center>',
       );
} else {
  print '<center>Sorry, this page is temporarily unavailable.</center>';
}

$page->footer;
