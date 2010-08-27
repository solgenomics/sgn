#!/usr/bin/perl -w
use strict;
use warnings;
use CXGN::Page;
use CXGN::Genomic::Chromat;
use CXGN::DB::Connection;
use CatalystX::GlobalContext '$c';

# KONI 2003 August 4
#
# New download script for chromatogram access.
our $trace_basepath;
our $page = CXGN::Page->new( "Trace Download", "Koni");

my $dbh = CXGN::DB::Connection->new();

#read_id is for a chromat from sgn.seqread
#chromat_id is for a chromat from genomic.chromat
my ($read_id,$chromat_id) = $page->get_arguments(qw/read_id chrid/);

unless ((defined($read_id) && $read_id =~ m/^[0-9]+$/)
	|| (defined($chromat_id) && $chromat_id =~ m/^[0-9]+$/)) {
  $page->message_page("Invalid: '$chromat_id', '$read_id'.\n");
#  invalid_search($page);
}

my ($tablename,$idcol);
my ($path, $name);
if($read_id) {
  my $schema = $dbh->qualify_schema('sgn');
  $tablename = "$schema.seqread";
  $idcol = 'read_id';
  ($path, $name) = $dbh->selectrow_array("SELECT trace_location,trace_name FROM $tablename WHERE $idcol=?",undef,$read_id||$chromat_id);
} elsif($chromat_id) {
    my $chromat = CXGN::Genomic::Chromat->retrieve($chromat_id);
    $path = $chromat->subpath;
    $name = $chromat->filename;
} else {
  $page->error_page('Invalid GET parameters');
}

($path && $name) || not_found($page, $read_id);

my $basename = $c->config->{'trace_path'}."/$path/$name";
my $full_pathname = '';

# The actual extension used should have been stored in the database, but it
# was not. This is because most chromatograms we had at the start did not have
# an extension. Overtime, it became clear that preserving the facility's 
# specified filename is necessary, thus conventions for file extenstions are
# not standardized. This nested loop below wastes some time, but is arguably
# robust and easily extended to new types.
#
# Add the extenstion used to seqread in the database to solve the problem
# cleanly, do NOT standardize the extensions used on the file system.
my $type_ext;
my $comp_ext;
foreach $type_ext ( '',qw/.ab1 .abi .scf .esd .SCF/) {
  foreach $comp_ext ( '',qw/.gz .Z .bz2/) {
    if ( -f "$basename$type_ext$comp_ext" ) {
      $full_pathname = $basename . $type_ext . $comp_ext;
      $name .= $type_ext . $comp_ext;
      last;
    }
  }
}

if (!$full_pathname) {
    print STDERR "Can't find chromatogram file at $basename";
  $page->message_page("This sequence does not seem to have an associated chromatogram.");
}

open F, "<$full_pathname"
 or $page->error_page("Failed to open chromatogram file for SGN-T$read_id ($!)");

print "Pragma: \"no-cache\"\nContent-Disposition: filename=$name\n";
print "Content-type: application/data\n\n";


while(read(F,$_,4096)) {
    print;
}

close F;

sub invalid_search {
  my ($page) = @_;

  $page->header();

  print <<EOF;

Requested search is invalid.
EOF

  $page->footer();
  exit 0;
}

sub not_found {
  my ($page, $id) = @_;

  $page->header();

  print <<EOF;

No chromatogram was found for SGN-T$id.

EOF

  $page->footer();
  exit 0;
}


