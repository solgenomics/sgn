package SGN::IntronFinder::Homology;

use strict;
use warnings;

use Carp;
use FindBin;
use POSIX qw(ceil);
use File::Spec;

use Memoize;

use Getopt::Std;
use Pod::Usage;

use Bio::Range;
use Bio::SearchIO;
use Bio::SeqIO;

#use Data::Dumper;

sub find_introns_txt {
    my ( $in_fh, $out_fh, $max_evalue, $gene_feature_file, $tempfile_dir,
        $protein_db_base )
      = @_;

    # validate our input sequences and copy them to a temp file
    my $seq_in = Bio::SeqIO->new( -fh => $in_fh, -format => 'fasta' );
    die "Invalid input FASTA sequence " unless $seq_in;

    my $temp_seq = File::Temp->new(
        DIR      => $tempfile_dir,
        TEMPLATE => $FindBin::Script . '-seq_in-XXXXXX',
        UNLINK   => 0,
    );
    $temp_seq->close;
    my $seq_out_temp = Bio::SeqIO->new(
        -file   => '>' . $temp_seq->filename,
        -format => 'fasta',
    );
    my $seq_count = 0;
    while ( my $seq = $seq_in->next_seq ) {
        $seq_count++;
        $seq_out_temp->write_seq($seq);
    }
    $seq_in = $seq_out_temp = undef;    #< undef the seqIOs to close and
                                        #  flush their files
    $seq_count or die "must provide at least one input sequence\n";

    # run blastall, feeding sequences on its STDIN and STDOUT
    my $blast_out = File::Temp->new(
        DIR      => $tempfile_dir,
        TEMPLATE => $FindBin::Script . '-blast_report-XXXXXX',
        UNLINK   => 1,
    );
    $blast_out->close;                  #< can't use the fh

    glob $protein_db_base.'.*'
       or die "BLAST db $protein_db_base.* not present on disk";

    my $cmd =
"blastall -d '$protein_db_base' -p 'blastx' -e $max_evalue < $temp_seq 2>&1 > $blast_out";
    system $cmd;
    if( $? ) {
        die "$! (\$?: $?) running $cmd: "
          .do {
              local $/;
              if( open my $f, $blast_out ) {
                  <$f>
              } else {
                  ''
              }
          };
    }

    # go through the blast report
    my $blast_in = Bio::SearchIO->new(
        -format => 'blast',
        -file   => $blast_out->filename,
    );

    # %unigenes maps the original identifier (EST) to an array (sequence
    # of unigene, unigene id, EST_hqi start coord (on EST), EST length,
    # EST sequence, EST start on unigene).
    while ( my $result = $blast_in->next_result ) {

        my $results_with_introns = 0;

        my $query = $result->query_name;

        $out_fh->print("Results for $query:\n\n");

        while ( my $hit = $result->next_hit ) {
            while ( my $hsp = $hit->next_hsp ) {

#check annotation of tair database for exon positions
#these are intron positions on protein, offset by where our hit starts.
#i.e. if the protein had an intron excised after the third amino acid, but our hit starts from the second amino acid, aa_intron_positions will contain 2.
#may contain fractions (introns that divide codons)
                my @aa_intron_positions = checkIntrons(
                    $gene_feature_file, $hit->name,
                    $hsp->start('hit'), $hsp->end('hit')
                );

                #	    print ("aa intron positions: \n");
                #	    printArray(@aa_intron_positions);

                #index in hit_string (aa) of real positions
                my @aa_visual_positions =
                  map { convertRealToVisual( $hsp->hit_string, $_ ); }
                  @aa_intron_positions;

                #	    printArray(@aa_visual_positions);
                #index in query_string(aa) of real positions

                my @query_aa_real_positions =
                  map { convertVisualToReal( $hsp->query_string, $_ ); }
                  @aa_visual_positions;

                #my  @query_aa_real_positions = @aa_visual_positions;
                #	    printArray(@query_aa_real_positions);

                my @cdna_intron_relative_positions =
                  map { $_ * 3 } @query_aa_real_positions;

                #	    printArray(@cdna_intron_relative_positions);

                my $reverse_orientation = 0;

                my $blast_frame =
                  ( $hsp->query->frame + 1 ) * $hsp->query->strand;

                if ( $blast_frame < 0 ) {
                    $reverse_orientation = 1;
                }

                my @cdna_intron_absolute_positions;
                if ($reverse_orientation) {
                    @cdna_intron_absolute_positions =
                      map { $hsp->end('query') - $_ - 1; }
                      @cdna_intron_relative_positions;
                }
                else {
                    @cdna_intron_absolute_positions =
                      map { $_ + $hsp->start('query') - 1; }
                      @cdna_intron_relative_positions;
                }

                # make sure we don't get intron positions like 45.99999999999
                @cdna_intron_absolute_positions =
                  map { roundToInt($_) } @cdna_intron_absolute_positions;

                if ( @aa_visual_positions
                  ) #make sure we have at least one intron in the alignment to print
                {
                    $results_with_introns++;    # results with introns count
                    if ($reverse_orientation) {
                        $out_fh->print("Frame for this query is negative.\n");
                    }

                    $out_fh->print(
                        @aa_visual_positions . " introns found in region.\n" );

                    displayAlignments( $out_fh, $query, $hsp, $hit,
                        $reverse_orientation );

                    displayIntrons( $out_fh, \@cdna_intron_absolute_positions,
                        \@aa_visual_positions, $hsp->query_string,
                        $hsp->hit_string, );
                    $out_fh->print("\n");
                }

                #	print "\n";
            }
        }
        $out_fh->print(
            "$results_with_introns results returned for query $query.\n\n");
    }
}

########## SUBROUTINES ################

# check if there is an intron in the given gene between start and end.
# start and end are amino acid #s, with first amino acid in protein = 1
# values will be offset from start, i.e. will return the number of aa.s
# expected between the value of start and a given intron, rather
# than absolute positions on the gene.
#
sub checkIntrons {
    my ( $gene_feature_file, $geneid, $start, $end ) = @_;

    my $features = _coding_region_index($gene_feature_file);
    my $frec     = $features->{$geneid}
      or return;
    my ( $coords, $orientation ) = @$frec;
    my @coords = @$coords;

    @coords = sort { $a <=> $b } @coords;

    # get rid of contiguous coding regions that don't have introns
    # between them
    @coords = deleteContiguousExons(@coords);

    # find # of amino acids coded by each coding region to do this, we
    # have to play with the coordinates if the protein is reverse
    # oriented

    if ( $orientation eq "reverse" ) {
        my $start_on_chrom = $coords[$#coords];

        @coords =
          sort { $a <=> $b }
          map  { ( $_ - $start_on_chrom ) * -1 } @coords;
    }
    my @aa_per_coding_region;

    for ( my $j = 0 ; $j < @coords ; $j += 2 ) {

        my $numaa = ( $coords[ $j + 1 ] - $coords[$j] + 1 ) / 3;
        push @aa_per_coding_region, $numaa;
    }

    my @relevant_introns;

    for ( my $j = 0, my $curTotal = 0 ; $j < @aa_per_coding_region ; $j++ ) {
        $curTotal += $aa_per_coding_region[$j];
        if ( $curTotal >= $end ) {
            last;
        }
        elsif ( $curTotal > $start ) {
            push @relevant_introns, $curTotal - $start + 1;

            #		print("total is $curTotal, start is $start\n");
        }
    }
    return @relevant_introns;
}

# first time checkIntrons called, cache our gene coding regions for this file in memory.  could have done this as a memoized subroutine
memoize('_coding_region_index');

sub _coding_region_index {
    my ($gene_feature_file) = @_;

    $gene_feature_file or die "must pass a gene feature file!\n";
    open my $datafile, '<', $gene_feature_file
      or die "couldn't open data file $gene_feature_file";

    my %coding_features;
    while (<$datafile>) {
        my ( undef, $geneid, undef, $type, $start, $stop, $length,
            $orientation ) = split;
        next unless $type eq 'coding_region';
        push @{ $coding_features{$geneid}[0] }, $start, $stop;
        $coding_features{$geneid}[1] = $orientation;
    }

    return \%coding_features;
}

#remove cases where we have coding region coordinates that do not actually have an intron between them, such as (0, 15, 15, 16) is reduced to (0, 16)
sub deleteContiguousExons(@) {
    my (@coords) = @_;
    my @tempcoords;

    for ( my $i = 0 ; ( $i < @coords ) ; $i++ ) {
        if ( not( $coords[ $i + 1 ] ) || ( $coords[$i] != $coords[ $i + 1 ] ) )
        {
            push @tempcoords, $coords[$i];
        }
        else {
            $i++;
        }
    }
    return @tempcoords;
}

#check that the introns are within the est, rather than elsewhere on the unigene.
sub removeOutofboundsIntrons {
    my ( $pos, $start, $end ) = @_;
    if ( $pos > $start && $pos < $end ) {
        return $pos;
    }
    else {
        return ();
    }
}

sub displayAlignments {

    my ( $out_fh, $query, $hsp, $hit, $reverse_orientation ) = @_;
    my $eststart;

    my $hit_name =
      $hit->name;   #$opt_w ? makeArabidopsisURL( $hit->name ) : ( $hit->name );

    my $query_start_pos =
        $reverse_orientation
      ? $hsp->end('query')
      : $hsp->start('query');

#we have no info in the database, just the sequence from the input file. since we blasted with the
#EST sequence anyway, no need for arithmetic, just print hsp and query.

    my $wslen = 20 - length($query);

    $out_fh->print( $query . ":" );

    $out_fh->print( ' ' x ( $wslen - length($query_start_pos) ) );

    $out_fh->print( $query_start_pos . "|" );
    $out_fh->print( $hsp->query_string . "\n" );

    #$eststart = $hsp->start('query');

    #blast results
    $wslen = 20 - ( length( $hit->name ) + length( $hsp->start('hit') ) );
    $out_fh->print( $hit_name . ":" );
    $out_fh->print( ' ' x $wslen );
    $out_fh->print( $hsp->start('hit') . "|" );
    $out_fh->print( $hsp->hit_string . "\n" );

    #    }
    return $reverse_orientation;
}

sub displayIntrons {
    my ( $out_fh, $intron_absolute_positions, $intron_visual_positions,
        $query_string, $hit_string, )
      = @_;

    my @intron_visual_positions   = @$intron_visual_positions;
    my @intron_absolute_positions = @$intron_absolute_positions;

    #    map {print $_, " "} @intron_visual_positions;

    my $intronstring   = "possible introns:    |";
    my $positionstring = "positions:           |";

    my $current_visual_intron   = shift @intron_visual_positions;
    my $current_absolute_intron = shift @intron_absolute_positions;

    for ( my $i = 1 ;
        $current_visual_intron && $current_absolute_intron ; $i++ )
    {
        if ( $i >= $current_visual_intron ) {
            $intronstring   .= "^";
            $positionstring .= $current_absolute_intron;

            #	    print "printing intron at $i\n";
            #	    print "cvi is $current_visual_intron\n";

            for ( my $j = 1 ; $j < length $current_absolute_intron ; $j++ ) {
                $intronstring .= " ";
                $i++;
            }
            $current_visual_intron   = shift @intron_visual_positions;
            $current_absolute_intron = shift @intron_absolute_positions;
        }
        else {
            $intronstring   .= " ";
            $positionstring .= " ";
        }
    }

    $out_fh->print( $intronstring . "\n" . $positionstring . "\n" );
}

sub convertRealToVisual {
    my ( $var1, $var2 ) = @_;
    return convertRealVisual( $var1, $var2, 1 );
}

sub convertVisualToReal {
    my ( $var1, $var2 ) = @_;
    return convertRealVisual( $var1, $var2, 0 );
}

# what position on the string does the dna/aa index correspond to, or vice versa, given gaps in the string.
# probably easier to do with regexps but i cant find the solution right now.
sub convertRealVisual {
    my ( $str, $pos, $r2v ) =
      @_;    #r2v is true if realtovisual, false if visualtoreal
    my $visualpos = 0;
    my $elem;

    my @strarray = split( //, $str );

    while ( $visualpos < $pos ) {
        $elem = $strarray[ $visualpos++ ];
        if ( $elem eq '-' ) {
            if ($r2v) { $pos += 1; }
            else      { $pos -= 1; }
        }
    }
    return ($pos);
}

sub printArray(@) {
    my (@array) = @_;
    map { print $_, " "; } @array;
    print "\n";
}

sub makeArabidopsisURL($) {
    my ($hit) = @_;
    my $url =
"http://www.arabidopsis.org/servlets/Search?type=general&name=GENEID&action=detail&method=4&sub_type=gene";
    $url =~ s/GENEID/$hit/;
    $url = "<a href=$url>$hit</a>";
}

#
# get file name from path
#

sub getFileName($) {
    my ($path) = @_;
    my $filename;
    ( $_, $_, $filename ) = File::Spec->splitpath($path);
    return $filename;
}

sub roundToInt($) {
    my ($num) = @_;
    my $res = int( $num + .5 * ( $num <=> 0 ) );

    return $res;

}

1;
