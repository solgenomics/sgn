
=head1 NAME

import_ncbi_mv_hs.pl --  make gff files from NCBI Map Viewer data files.

=head2 SYNOPSIS

perl import_ncbi_mv_hs.pl --type type [options]

=head2 A QUICK RUN

Download from ftp://ftp.ncbi.nih.gov/genomes/H_sapiens/mapview/
(or the most current directory) the files

 seq_gene.md.gz
 seq_gene.q.gz

to the same directory as import_ncbi_mv_hs.pl and execute the command

 perl import_ncbi_mv_hs.pl --type gene

This creates the file seq_gene.gff which can be loaded into a
gbrowse database using bp_load_gff.pl.

=head2 DESCRIPTION

This script reads two kinds of input files from the NCBI Map Viewer FTP site. The
source for human input files is

 ftp://ftp.ncbi.nih.gov/genomes/H_sapiens/mapview

which contains subdirectories for the various builds. For example,
mapview/seq_gene.md.gz would be an input file for use with
the subroutine mk_seq_gene.

At the moment this script will import the files seq_gene.md
(essentially records from the Entrez Gene database) and seq_sts.md
(the UniSTS database). However there are many other kinds of data
available from the Map Viewer FTP site.

This script does not load the gff files into the database.  This can
be achieved by running the script bp_load_gff.pl with the output files
(gff files) from import_ncbi_mv_hs.pl.

The argument 'type' to the option '--type' indicates what kind of
Map Viewer file to import.

 type   Map Viewer file
 ----   ---------------
 gene   seq_gene.md. The path of this file can be indicated
        with the --seq_gene option. The script can read
        directly from the compressed version seq_gene.md.gz.

 sts    seq_sts.md. Similary, use the --seq_sts option to specify
        the path.

Options (default)

 --type        Type of file: gene, sts. Explained above.
 --seq_gene    Path for file seq_gene.md, text or *.gz (seq_gene.md.gz)
 --gene_q      Path for file gene.q, text or *.gz (gene.q.gz). See hs_mk_seq_gene.
 --seq_sts     Path for file seq_sts.md, text or *.gz (seq_sts.md.gz)
 --chromosome  Only import records for this chromosome
 --gff         Path of gff file to create (default=seq_gene.gff for type=gene, etc)
 --min_pos      Minimum chromosomal position to import
 --max_pos      Maximum chromosomal position to import

Example:

 perl import_ncbi_mv_hs.pl --type gene --chr 2 --gff seq_gene_chr2.gff

This imports the file seq_gene.gz

=head2 AUTHOR

Scott Saccone (ssaccone@han.wustl.edu)

=cut

use strict;
use warnings;

use Getopt::Long;
use File::Basename;

sub hs_mk_seq_gene;
sub hs_read_gene_q;

my ($type,$seq_gene,$gene_q,$seq_sts,$gff,
    $assembly,$chromosome,$min_pos,$max_pos);

my $gunzip_cmd = 'gunzip --to-stdout';

my $opt = GetOptions("type=s"=>\$type,
		     "seq_gene=s"=>\$seq_gene,
		     "gene_q=s"=>\$gene_q,
		     "seq_sts=s"=>\$seq_sts,
		     "gff=s"=>\$gff,
		     "assembly=s"=>\$assembly,
		     "chromosome=s"=>\$chromosome,
		     "min_pos=i"=>\$min_pos,
		     "max_pos=i"=>\$max_pos);

my $self = basename($0);

die <<USAGE if ( (! defined($opt)) || (! defined $type) );
Usage: $self --type type [options]

See 'perldoc $self' for more information.
USAGE

hs_mk_seq_gene(-seq_gene=>$seq_gene,
	       -gene_q=>$gene_q,
	       -gff=>$gff,
	       -assembly=>$assembly,
	       -chromosome=>$chromosome,
	       -min_pos=>$min_pos,
	       -max_pos=>$max_pos
	      ) if $type eq 'gene';

hs_mk_seq_sts(-seq_sts=>$seq_gene,
	      -gff=>$gff,
	      -assembly=>$assembly,
	      -chromosome=>$chromosome,
	      -min_pos=>$min_pos,
	      -max_pos=>$max_pos
	      ) if $type eq 'sts';

die <<USAGE;

Error: choices for argument --type:
 gene
 sts

See 'perldoc $self' for more information.
USAGE

=head2 hs_mk_seq_gene

Example:

 hs_mk_seq_gene(-seq_gene=>'seq_gene.md.gz',
	        -gene_q=>'gene.q',
	        -gff=>'seq_gene_chr1.gff',
	        -assembly=>'reference',
	        -chromosome=>1,
	        -min_pos=>undef,
	        -max_pos=>undef
	       );

This converts the human Map Viewer file seq_gene.md to gff format. The
gff source field is named "ncbi:mapview:$assembly" where $assembly is
specified as an option whose default is 'reference'. Optionally, gene descriptions
can be obtained from the Map Viewer file 'gene.q' in which case the
group field of the gff gets a 'Note' attribute; for example
'Note "similar to beta-tubulin 4Q"'.

Format of seq_gene.md:
 tab delimited
 header line 1
 fields:
  0  taxid
  1  chr
  2  chrStart
  3  chrEnd
  4  orientation
  5  contig
  6  cnt_start
  7  cnt_end
  8  cnt_orient
  9  featureName
  10 featureId
  11 featureType
  12 groupLabel
  13 transcript
  14 weight

Notes on the fields:

 featureId: has the form GeneID:n where n is the Entrez Gene ID. This
is sometimes the same as the LocusLink ID but I believe LocusLink
is being phased out and these IDs may not always agree. Features that are
grouped together by a common featureId will have a common group id
in the gff file. Then the transcript aggregator can then be applied.

 featureType: is used to define the method field in the gff
record. The values I've seen are GENE,UTR,CDS and PSEUDO. I think
the current transcript aggregator only recognizes CDS (the
GENE records use the 'transcript' method). Perhaps UTR must
be converted to 5'UTR and 3'UTR somehow.

 groupLabel: the 'assembly' I believe: 'reference', 'HSC_TCAG' or 'DR51'.

Options (default):
 -seq_gene   mapview file with gene locations, text or *.gz file (seq_gene.md.gz)
 -gene_q     mapview file with gene descriptions, text or *.gz file (gene.q.gz)
 -chromosome only make records for this chromosome
 -min_pos    minimum chromosomal position
 -max_pos    maximum chromosomal position
 -assembly   which assembly to use (reference)

=cut

sub hs_mk_seq_gene {

  my (%options) = @_;
  my $subname = 'hs_mk_seq_gene';

  my $gene_q = $options{-gene_q};
  $gene_q = 'gene.q.gz' unless $gene_q;
  my $full_desc = hs_read_gene_q($gene_q) if $gene_q;

  my $seq_gene = $options{-seq_gene};
  $seq_gene = 'seq_gene.md.gz' unless $seq_gene;

  if ($seq_gene =~ /\.gz$/) {
    open SEQ_GENE,"$gunzip_cmd $seq_gene|" or die "Error($subname): cannot open $seq_gene";
  } else {
    open SEQ_GENE,"<$seq_gene" or die "Error($subname): cannot open $seq_gene";
  }

  my $gff_file = $options{-gff};
  $gff_file = "seq_gene.gff" unless $gff_file;

  open GFF_FILE,">$gff_file" or die "Error($subname): cannot open $gff_file";

  my ($chr,$min_pos,$max_pos,$assembly) = @options{qw(-chromosome -min_pos -max_pos -assembly)};
  $assembly = 'reference' unless $assembly;

  my @field_names = qw(chr pos1 pos2 strand featureName featureId featureType groupLabel);
  my @field_positions = (1..4,9..12);

  print "Reading $seq_gene\n";

  my %gene_names;
  # key=GeneID value=featureName for the record with featureType='GENE'
  # e.g. featureID='GeneID:1139' featureType='GENE' featureName='CHRNA7'

  my @data;

  $_ = <SEQ_GENE>; # Header

  for (<SEQ_GENE>) {
    chomp;

    my $obs = {};
    @$obs{@field_names} = (split '\t')[@field_positions];

    next unless $obs->{chr} && $obs->{chr} =~ /(\d+|X|Y)/;
    next if $chr && ($obs->{chr} ne $chr);

    next unless $obs->{featureId} =~ /GeneID:(\d+)/;
    $obs->{GeneID} = $1; # May need ll_id to get gene description

    next unless $obs->{pos1} && $obs->{pos2};
    next if ($min_pos && ($obs->{pos1} < $min_pos))
      || ($max_pos && ($obs->{pos2} > $max_pos));

    my $grp;
    next unless ($grp = $obs->{groupLabel}) && ($grp eq $assembly);
    next unless my $featureType = $obs->{featureType};

    $obs->{gff_source} = "ncbi:mapview:$grp";

    if ($featureType eq 'GENE') { # Use to make group id in gff records below
      $gene_names{$obs->{GeneID}} = $obs->{featureName};
      $obs->{gff_method} = 'transcript';
    } else {
      $obs->{gff_method} = $featureType; # E.g.: CDS,UTR.
    }

    push @data, $obs;
  }
  close SEQ_GENE;

  print "Creating $gff_file\n";

  # Go back and get group id using featureName of featureType='GENE' record
  for my $obs (@data) {
    my $gene_id = $obs->{GeneID};
    my $fname = $obs->{featureName};

    die "Error($subname): no featureName found for GeneID '$gene_id', featureName=$fname"
      unless my $group_id = $gene_names{$obs->{GeneID}};

    my $group = "Transcript \"$group_id\"; Name \"$group_id\";";

    # Get gene description from gene_q data if possible
    if ($full_desc && ($obs->{gff_method} eq 'transcript')
	&& (my $desc = $full_desc->[$gene_id]) ) {
      $group .= " Note \"$desc\";";
    }

    my @fields = ("Chr$obs->{chr}",@$obs{qw(gff_source gff_method pos1 pos2)},
		  ".",$obs->{strand},".",$group);
    print GFF_FILE join "\t",@fields,"\n";
  }
  close GFF_FILE;
  @data = ();
  @$full_desc = ();

  exit 0;
}

=head2 read_seq_q

Read Map Viewer file seq_q and store the full gene
descriptions. Used by hs_mk_seq_gene.

Format of seq_q:
 tab delimited
 header at line 1
 field 0: GeneID
 field 7: full description

=cut

sub hs_read_gene_q {

  my $gene_q = shift;
  my $subname = 'hs_read_gene_q';

  unless (-e $gene_q) { # User may choose not to import gene descriptions
    print "Note: \"$gene_q\" does not exist. Will not import gene descriptions.\n";
    return undef;
  }

  if ( $gene_q =~ /\.gz$/ ) {
    if (! open GENE_Q,"$gunzip_cmd $gene_q|") {
      print "\nError($subname): cannot open $gene_q: $! (gunzip returned $?)";
      return undef;
    }
  } elsif ( ! open GENE_Q,"<$gene_q" ) {
    print "\nError($subname): cannot open $gene_q: $!";
    return undef;
  }

  # $full_desc = array ref: index = GeneID, value = full gene description
  my $full_desc = [];

  print "Reading $gene_q\n";
  $_ = <GENE_Q>; # Header
  while (<GENE_Q>) {
    my ($featureID,$desc) = (split /\t/)[0,7];
    next unless $featureID =~ /GeneID:(\d+)/;
    $full_desc->[$1] = $desc;
  }
  close GENE_Q;

  return $full_desc;
}


=head2 hs_mk_seq_sts

Example:

 hs_mk_seq_sts(-seq_sts=>'seq_sts.md.gz',
	       -gff=>'seq_sts_chr1.gff',
	       -assembly=>'reference',
	       -chromosome=>1,
	       -min_pos=>undef,
	       -max_pos=>undef
	      );

Convert human Map Viewer file seq_sts.md to gff format. The gff source
is 'sts' and the gff method is "ncbi:mapview:$assembly" where
$assembly is specified as an option whose default is 'reference'. The
group field is of the form 'STS "name"; Name "name"' where name is
the featureName field from the Map Viewer file. The group fields
will also contain 'UniSTS_ID n' if the UniSTS ID is available
in the Map Viewer record.

Format of seq_sts.md:
 tab delimited
 header line 1
 fields:
  0  taxid
  1  chr
  2  chrStart
  3  chrEnd
  4  orientation
  5  contig
  6  cnt_start
  7  cnt_end
  8  cnt_orient
  9  featureName
  10 featureId
  11 featureType
  12 groupLabel
  13 weight

Notes on the fields:

 featureId: has the form UniSTS:n where n is the UniSTS ID.

 groupLabel: see hs_mk_seq_gene.

Options (default):
 -seq_sts    Map Viewer file with sts locations. Can read directly from *.gz file (seq_sts.md.gz)
 -chromosome only make records for this chromosome
 -min_pos    minimum chromosomal position
 -max_pos    maximum chromosomal position
 -assembly   assembly to use (reference)

=cut

sub hs_mk_seq_sts {

  my (%options) = @_;
  my $subname = 'hs_mk_seq_sts';

  my $seq_sts = $options{-seq_sts};
  $seq_sts = 'seq_sts.md.gz' unless $seq_sts;

  if ($seq_sts =~ /\.gz$/) {
    open SEQ_STS,"$gunzip_cmd $seq_sts|" or die "Error($subname): cannot open $seq_sts";
  } else {
    open SEQ_STS,"<$seq_sts" or die "Error($subname): cannot open $seq_sts";
  }

  my $gff_file = $options{-gff};
  $gff_file = "seq_sts.gff" unless $gff_file;

  open GFF_FILE,">$gff_file" or die "Error($subname): cannot open $gff_file";

  my ($chr,$min_pos,$max_pos,$assembly) = @options{qw(-chromosome -min_pos -max_pos -assembly)};
  $assembly = 'reference' unless $assembly;

  my @field_names = qw(chr pos1 pos2 strand featureName featureId featureType groupLabel);
  my @field_positions = (1..4,9..12);

  print "Reading $seq_sts\n";
  print "Creating $gff_file\n";

  $_ = <SEQ_STS>; # Header
 SEQ_STS_LOOP: while (<SEQ_STS>) {
    chomp;

    my $obs = {};
    @$obs{@field_names} = (split '\t')[@field_positions];
    for my $field_name (@field_names) {
      next SEQ_STS_LOOP unless $obs->{$field_name};
    }

    next unless ($obs->{chr} =~ /(\d+|X|Y)/);
    next if $chr && ($obs->{chr} ne $chr);

    next if ($min_pos && ($obs->{pos1} < $min_pos)) || ($max_pos && ($obs->{pos2} > $max_pos));

    my $grp_lbl;
    next unless ($grp_lbl = $obs->{groupLabel}) eq $assembly;
    my $gff_source = "ncbi:mapview:$grp_lbl";
    my $gff_method = 'sts';
    my $fname = $obs->{featureName};
    my $gff_group = "STS \"$fname\"; Name \"$fname\";";

    $gff_group .= " UniSTS_ID $1;" if $obs->{featureId} =~ /UniSTS:(\d+)/;

    my @fields = ("Chr$obs->{chr}",$gff_source,$gff_method,@$obs{qw(pos1 pos2)},
		  ".",$obs->{strand},".",$gff_group);
    print GFF_FILE join "\t",@fields,"\n";
  }
  close SEQ_STS;
  close GFF_FILE;

  exit 0;
}

__END__
