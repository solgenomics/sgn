#!/usr/bin/perl

eval 'exec /usr/bin/perl -w -S $0 ${1+"$@"}'
  if 0;    # not running under some shell

use strict;
use warnings;
use English;

use FindBin;
use File::Spec;

use Getopt::Std;
use Pod::Usage;

#use CXGN::DB::Connection;
use CXGN::Tools::Script qw/ in_fh out_fh /;
#use CXGN::VHost;

use SGN::sIntronFinder::Homology;


###### DEFAULTS ##########

my $default_max_evalue = 1e-50;    #< update the perldoc at the bottom of
                                   # the file if you change this
##########################



# check our external tool dependencies
foreach my $tool (qw/ blastall /) {
  `which $tool`
    or die
      "Program '$tool' must be in executable path to use this script.  Aborting.\n";
}


### parse and validate command line args
our %opt;
getopts( 'i:o:f:e:t:', \%opt ) or pod2usage(1);

@ARGV == 1 or pod2usage(1);

# check our protein db argument
my $protein_db_base = shift @ARGV;
{
    my $bad_db;
    foreach (qw/ psq phr pin psd psi /) {
        my $dbfile = $protein_db_base . ".$_";
        unless ( -r $dbfile ) {
            warn "Protein db file '$dbfile' not found.\n";
            $bad_db = 1;
        }
    }
    $bad_db and die "Invalid protein db '$protein_db_base'.  Quitting.\n";
}

# open our input and output filehandles ( see CXGN::Tools::Script )
my $in_fh  = in_fh $opt{i};
my $out_fh = out_fh $opt{o};

# validate our max evalue
my $max_evalue = defined $opt{e} ? $opt{e} : $default_max_evalue;
$max_evalue == $max_evalue
  or die "-e option must be numeric\n";

# validate our -f (gene feature file)
my $gene_feature_file = $opt{f};
if( $gene_feature_file ) {
  -f $gene_feature_file
    or die "gene feature file '$gene_feature_file' not found\n";
  -r $gene_feature_file
    or die "gene feature file '$gene_feature_file' not readable\n";
}

# validate our -t tempfile dir
my $tempfile_dir = defined $opt{t} ? $opt{t} : File::Spec->tmpdir;
-d $tempfile_dir or die "tempfile dir '$tempfile_dir' does not exist\n";
-w $tempfile_dir or die "tempfile dir '$tempfile_dir' is not writable\n";

# fake-assedly factor this out into a module
SGN::IntronFinder::Homology::find_introns_txt( $in_fh, $out_fh, $max_evalue, $gene_feature_file, $tempfile_dir, $protein_db_base );

__END__

=head1 NAME

intron_finder_homology.pl - finds possible intron sites in transcript
sequences by aligning sequences to Arabidopsis using BLAST and then
parsing the introns from the known intron positions in Arabidopsis.

=head1 SYNOPSIS

  intron_finder_homology.pl [options] protein_blast_db_name

  Required argument is the protein database basename to use for
  running BLAST. This file should be Arabidopsis and the gene feature
  file needs to correspond to the sequences in this file. (Download
  both from TAIR).

  Options:


    -e <evalue number>
     maximum e-value for reporting a match.
     default: 1e-50

    -i <file>
     input sequence file to read from.  if not given, reads sequence
     from stdin.

    -o <file>
     output file to write to.  if not given, writes to stdout.

    -f <file>
     optional gene feature file (TODO: document further)

    -t <dir>
     directory in which to put temp files for this run.
      

=head1 REQUIRES BLASTALL IN EXEC PATH

Requires that the 'blastall' executable be installed and available on
the executable path. Set your PATH environment variable before running
if you need to explicitly provide a path for finding blastall.

=head1 FEATURE FILE FORMAT

  Structure of feature file. This file can be downloaded from the TAIR website at:
  ftp://ftp.arabidopsis.org/ ... somewhere.

  chromosome      gene name       TAIR accession  feature start   stop    length  orientation
  1       AT1G05850.1     gene:2198687    GENE    1766502 1768662 2161    reverse
  1       AT1G05850.1     gene:2198687    exon    1766502 1767249 748     reverse
  1       AT1G05850.1     gene:2198687    ORF     1766832 1768116 1285    reverse
  1       AT1G05850.1     gene:2198687    coding_region   1766832 1767249 418     reverse
  1       AT1G05850.1     gene:2198687    exon    1767351 1767510 160     reverse
  1       AT1G05850.1     gene:2198687    coding_region   1767351 1767510 160     reverse
  1       AT1G05850.1     gene:2198687    exon    1767729 1768150 422     reverse
  1       AT1G05850.1     gene:2198687    coding_region   1767729 1768116 388     reverse
  1       AT1G05850.1     gene:2198687    exon    1768547 1768662 116     reverse
  1       AT1G05770.1     gene:2198692    GENE    1725546 1726249 704     reverse

=head1 MAINTAINER

your name here

=head1 AUTHOR(S)

Your Name, E<lt>you@cornell.eduE<gt>

=head1 COPYRIGHT & LICENSE

Copyright 2009 The Boyce Thompson Institute for Plant Research

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
