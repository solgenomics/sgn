package SGN::View::Feature;
use strict;
use warnings;

use base 'Exporter';

use HTML::Entities;
use List::Util qw/ sum /;
use List::MoreUtils qw/ any uniq /;

use Bio::Seq;

use CXGN::Tools::Text qw/commify_number/;
use CXGN::Tools::Identifiers;


our @EXPORT_OK = qw/
    related_stats feature_table
    feature_link
    cvterm_link
    organism_link feature_length
    mrna_cds_protein_sequence
    description_featureprop_types
    get_descriptions
    location_list_html
    location_list
    location_string
    location_string_html
    type_name
    feature_types
    feature_organisms
/;



sub feature_organisms {
    my ($schema) = @_;
    return [
        [ 0, '' ],
        map [ $_->organism_id, $_->species ],
        $schema
             ->resultset('Sequence::Feature')
             ->search_related('organism' , {}, {
                 select   => [qw[ organism.organism_id species ]],
                 distinct => 1,
                 order_by => 'species',
               })
    ];
}

sub feature_types {
    my ($schema) = @_;

    my $ref = [
        map [$_->cvterm_id,$_->name],
        $schema
    ->resultset('Sequence::Feature')
    ->search_related(
        'type',
        {},
        { select => [qw[ cvterm_id type.name ]],
          group_by => [qw[ cvterm_id type.name ]],
          order_by => 'type.name',
        },
    )
    ];
    # add an empty option
    unshift @$ref , ['0', ''];
    return $ref;
}

sub type_name {
    cvterm_name( shift->type, @_ );
}

sub cvterm_name {
    my ($cvt, $caps) = @_;
    ( my $n = $cvt->name ) =~ s/_/ /g;
    if( $caps ) {
        $n =~ s/(\S+)/lc($1) eq $1 ? ucfirst($1) : $1/e;
    }
    return $n;
}

sub description_featureprop_types {
    shift->result_source->schema
         ->resultset('Cv::Cvterm')
         ->search({
             name => [ 'Note',
                       'functional_description',
                       'Description',
                       'description',
                     ],
           })
}

sub get_descriptions {
    my ( $feature, $plain ) = @_;

    my $desc_types =
        description_featureprop_types( $feature )
            ->get_column('cvterm_id')
            ->as_query;

    my @descriptions =
        $feature->search_related('featureprops',
                                 { type_id => { -in => $desc_types } },
                                 { order_by => 'rank' },
                                )
                ->get_column('value')
                ->all;


    return @descriptions if defined $plain;

    s/(\S+)/my $id = $1; CXGN::Tools::Identifiers::link_identifier($id) || $id/ge for @descriptions;

    return @descriptions;
}

sub location_string_html {
    my ( $id, $start, $end, $strand ) = @_;
    if( @_ == 1 ) {
        my $loc = shift;
        $id     = feature_link($loc->srcfeature);
        $start  = $loc->fmin+1;
        $end    = $loc->fmax;
        $strand = $loc->strand;
    }
    ( $start, $end ) = ( $end, $start ) if $strand && $strand == -1;
    return "$id:$start..$end";
}

sub location_string {
    my ( $id, $start, $end, $strand ) = @_;
    if( @_ == 1 ) {
        my $loc = shift;
        $id     = $loc->srcfeature->name;
        $start  = $loc->fmin+1;
        $end    = $loc->fmax;
        $strand = $loc->strand;
    }
    ( $start, $end ) = ( $end, $start ) if $strand && $strand == -1;
    return "$id:$start..$end";
}

sub location_list_html {
    my ($feature, $featurelocs) = @_;
    my @coords = map { location_string_html($_) }
        (  #$featurelocs ? $featurelocs->all
          #             : $feature->featureloc_features->all );
	  $featurelocs ? $featurelocs->search({locgroup => 0,},)->all
                       : $feature->featureloc_features->search({locgroup => 0,},)->all)
        or return '<span class="ghosted">none</span>';
    return @coords;
}
sub location_list {
    my ($feature, $featurelocs) = @_;
    print STDERR "\n\nLOCATON LIST\n\n";
    return map { ($_->srcfeature ? $_->srcfeature->name : '<span class="ghosted">null</span>') . ':' . ($_->fmin+1) . '..' . $_->fmax }
        ( #$featurelocs ? $featurelocs->all
          #             : $feature->featureloc_features->all );
    $featurelocs ? $featurelocs->search({locgroup => 0,},)->all
                       : $feature->featureloc_features->search({locgroup => 0,},)->all );
}

sub related_stats {
    my ($features) = @_;
    my $stats = { };
    my $total = scalar @$features;
    for my $f (@$features) {
            $stats->{cvterm_link($f->type)}++;
    }
    my $data = [ ];
    for my $k (sort keys %$stats) {
        push @$data, [ $stats->{$k}, $k ];
    }
    if( 1 < scalar keys %$stats ) {
        push @$data, [ $total, "<b>Total</b>" ];
    }
    return $data;
}

sub feature_table {
    my ( $features, $reference_sequence, $omit_columns ) = @_;

    { no warnings 'uninitialized';
      $omit_columns ||= [];
      $omit_columns = [$omit_columns] unless ref $omit_columns eq 'ARRAY';
    }

    my @data;
    for my $f (sort { $a->name cmp $b->name } @$features) {
        my @ref_condition =
            $reference_sequence ? ( srcfeature_id => $reference_sequence->feature_id )
                                : ();

        my @locations = $f->search_related('featureloc_features', {
            @ref_condition,
	    locgroup => 0,
           },
           { order_by => 'feature_id' }
          );

        if( @locations ) {
        # Add a row for every featureloc
            my $first_location = 0;
            for my $loc (@locations) {
                my $ref = $loc->srcfeature;
                my ($start,$end) = ($loc->fmin+1, $loc->fmax);
                push @data, [
                    ( $first_location++
                          ? ('','','')
                          : ( organism_link( $f->organism ),
                              cvterm_link($f->type),
                              feature_link($f),
                            )
                    ),
                    ($ref ? $ref->name : '<span class="ghosted">null</span>').":$start..$end",
                    commify_number( feature_length( $f, $loc ) ) || undef,
                    $loc->strand ? ( $loc->strand == 1 ? '+' : '-' ) : undef,
                    $loc->phase || undef,
                    ];
            }
        }
        else {
            my $nl = 'not located';
            if( $reference_sequence ) {
                $nl .= " on ".encode_entities( $reference_sequence->name )
            }
            push @data, [
                organism_link( $f->organism ),
                cvterm_link($f->type),
                feature_link($f),
                qq|<span class="ghosted">$nl</span>|,
                commify_number( feature_length( $f, undef ) ) || undef,
                undef,
                undef,
            ];
        }
    }

    my @headings = ( "Organism", "Type", "Name", "Location", "Length", "Strand", "Phase" );

    my @align = map 'l', @headings;

    # omit any columns that are *all* undefined, or that we were
    # requested to omit
    my @cols_to_omit = uniq(
        do {
            my %heading_index = do { my $i = 0; map { lc $_ => $i++ } @headings };
            (map {
                my $i = $heading_index{lc $_};
                defined $i or die "$_ column not found";
                $i
             } @$omit_columns
            )
        },
      );
    for my $t ( [\@headings], \@data, [\@align] ) {
        for my $row ( @$t ) {
            splice( @$row, $_, 1 ) for @cols_to_omit;
        }
    }

    # make html for any other undef cells
    for (@data) {
        for (@$_) {
            $_ = '<span class="ghosted">n/a</span>' unless defined;
        }
    }

    return ( headings => \@headings, data => \@data, __align => \@align, __alt_freq => 0 , __border => 1 );
}

# try to figure out the "length" of a feature, which will vary for different features
sub feature_length {
    my ( $feature, $location ) = @_;

    $location = $location->first
        if $location && $location->isa('DBIx::Class::ResultSet');

    my $type      = $feature->type;
    my $type_name = $type->name;

    # firstly, for any feature, trust the length of its residues if it has them
    if( my $seqlen = $feature->seqlen || $feature->residues && length $feature->residues ) {
        return $seqlen;
    }
    # for some features, can say that its length is the length of its location
    elsif( any { $type_name eq $_ } qw( exon gene ) ) {
        return unless $location;
        return $location->fmax - $location->fmin;
    }
    return;
}

sub _feature_search_string {
    my ($fl) = @_;
    return '' unless $fl;
    return ($fl->srcfeature ? $fl->srcfeature->name : '<span class="ghosted">null</span>') . ':'. ($fl->fmin+1) . '..' . $fl->fmax;
}


### XXX TODO: A lot of these _link and sequence functions need to be
### moved to controller code.

sub feature_link {
    my ($feature) = @_;
    return '<span class="ghosted">null</span>' unless $feature;
    my $id   = $feature->feature_id;
    my $name = $feature->name;
    return qq{<a href="/feature/$id/details">$name</a>};
}

sub organism_link {
    my ($organism) = @_;
    my $id      = $organism->organism_id;
    my $species = $organism->species;
    return qq{<a class="species_binomial" href="/chado/organism.pl?organism_id=$id">$species</a>};
}

sub cvterm_link {
    my ( $cvt, $caps ) = @_;
    my $name = cvterm_name( $cvt, $caps );
    my $id   = $cvt->id;
    return qq{<a href="/cvterm/$id/view">$name</a>};
}

sub mrna_cds_protein_sequence {
    my ($mrna_feature) = @_;

    # if we were actually passed a polypeptide, get its mrna(s) and
    # recurse
    if( $mrna_feature->type->name eq 'polypeptide' ) {
        return
            map mrna_cds_protein_sequence( $_ ),
            $mrna_feature->search_related('feature_relationship_subjects',
                    { 'me.type_id' => {
                        -in => $mrna_feature->result_source->schema
                                            ->resultset('Cv::Cvterm')
                                            ->search({name => 'derives_from'})
                                            ->get_column('cvterm_id')
                                            ->as_query,
                    },
                  },
               )
               ->search_related('object');
    }

    my $description = join ', ', get_descriptions( $mrna_feature, 'no html' );
    my $peptide     = _peptides_rs( $mrna_feature )->first;

    my @exon_locations = _exon_rs( $mrna_feature )->all;
    unless( @exon_locations ) {
        # cannot calculate the cds and protein without exons, because
        # UTRs can sometimes have introns in them.  without knowing
        # the exon structure, we don't know how much to cut off of the
        # UTRs
        return [
            $mrna_feature->subseq(1,1)        ? $mrna_feature : undef,
            undef,
            $peptide && $peptide->subseq(1,1) ? $peptide      : undef,
        ];
    }

    my $mrna_seq = $mrna_feature->subseq(1,1) ? $mrna_feature : _make_mrna_seq( $mrna_feature, $description, \@exon_locations );
    my $peptide_loc = $peptide && _peptide_loc($peptide)->first;

    # just return the mrna seq and nothing else if we have no peptide
    # or the peptide is not located
    unless( $peptide && $peptide_loc ) {
        return [ $mrna_seq, undef, undef ] unless $peptide && $peptide_loc;
    }

    my $cds_seq = Bio::PrimarySeq->new(
        -id   => $mrna_seq->display_name,
        -desc => $description,
        -seq  => $mrna_seq->seq,
     );
    my ( $trim_from_left, $trim_from_right ) = _calculate_cdna_utr_lengths(
        _loc2range( $peptide_loc ),
        [ map _loc2range( $_), @exon_locations ],
     );

    if( $trim_from_left || $trim_from_right ) {
        $cds_seq = $cds_seq->trunc( 1+$trim_from_left, $mrna_seq->length - $trim_from_right );
    }

    ##Get the protein sequence from the peptide object (stored in the database in the residues field of the feature table)
    my $protein_seq  = Bio::PrimarySeq->new(
        -id   => $mrna_seq->display_name,
        -desc => $description,
        -seq  => $peptide->residues,
     );

    #Get the protein seq from translated CDS if no residues are found for polypeptide in the DB
    if ( !$protein_seq->seq ) {
      $protein_seq = $cds_seq->translate;
    }

    return [ $mrna_seq, $cds_seq, $protein_seq ];
}

sub _make_mrna_seq {
    my ( $mrna_feat, $description, $exons ) = @_;

    # NOTE: doing this subseq math in 0-based coords
    my $span_start  = $exons->[0]->fmin;
    my $span_end    = $exons->[-1]->fmax-1;

    # 0 1 2 3 4 5 6 7 8  interbase (Chado)
    #  G|C|C|A|T|G|T|A
    #  0 1 2 3 4 5 6 7   0-based   (substr)
    #  1 2 3 4 5 6 7 8   1-based   (BioPerl)

    # recall: the exons are in sorted order
    my $span_seq = $exons->[0]->srcfeature->subseq( $span_start+1, $span_end+1 ); #< 1-based
    my $mrna_sequence = join '', map { substr($span_seq, $_->fmin - $span_start, $_->fmax - $_->fmin ) } @$exons;

    my $mrna_seq = Bio::PrimarySeq->new(
        -id   => $mrna_feat->name,
        -desc => $description,
        -seq  => $mrna_sequence,
    );

    $mrna_seq = $mrna_seq->revcom if $exons->[0]->strand == -1;

    return $mrna_seq;
}

sub _loc2range {
    my ( $loc ) = @_;
    return $loc->to_range if $loc->can('to_range');
    return Bio::Range->new(
        -start  => $loc->fmin + 1,
        -end    => $loc->fmax,
        -strand => $loc->strand,
      );
}

# given the range of the peptide and the ranges of each of the exons
# (as Bio::RangeI's), calculate how many bases should be trimmed off
# of each end of the cDNA (i.e. mRNA) seq to get the CDS seq
sub _calculate_cdna_utr_lengths {
    my ( $peptide, $exons ) = @_;

    my ( $trim_left, $trim_right ) = ( 0, 0 );

    # calculate trim_fmin if necessary
    if( $exons->[0]->start < $peptide->start ) {

        $trim_left =
            sum
            map {
                $_->overlaps($peptide)
                    ? $peptide->start - $_->start
                    : $_->length
            }
            grep $_->start < $peptide->start, # find exons that overlap the UTR
            @$exons
    }

    # calculate trim_fmax if necessary
    if( $exons->[-1]->end > $peptide->end ) {
        $trim_right =
            sum
            map {
                $_->overlaps($peptide)
                    ? $_->end - $peptide->end
                    : $_->length
            }
            grep $_->end > $peptide->end, # find exons that overlap the UTR
            @$exons
    }

    return $exons->[0]->strand == -1 ? ($trim_right, $trim_left) : ( $trim_left, $trim_right );
}

sub _peptides_rs {
    my ( $mrna_feature ) = @_;

    $mrna_feature
        ->feature_relationship_objects({
            'me.type_id' => {
                -in => _cvterm_rs( $mrna_feature, 'relationship', 'derives_from' )
                         ->get_column('cvterm_id')
                         ->as_query,
            },
          })
        ->search_related( 'subject', {
            'subject.type_id' => {
                -in => _cvterm_rs( $mrna_feature, 'sequence', 'polypeptide' )
                         ->get_column('cvterm_id')
                         ->as_query,
            },
           })
    }
sub _peptide_loc {
    my ($rs) = @_;
    $rs->search_related( 'featureloc_features', {
            #srcfeature_id => { -not => undef },
	     srcfeature_id => { -not => undef }, locgroup => 0
          },
          { # Don't prefetch srcfeatures, it significantly slows down the query
            # prefetch => 'srcfeature',
            order_by => 'fmin',
          },
         );
}

sub _exon_rs {
    my ( $mrna_feature ) = @_;

    my $rs = $mrna_feature->feature_relationship_objects({
            'me.type_id' => {
                -in => _cvterm_rs( $mrna_feature, 'relationship', 'part_of' )
                         ->get_column('cvterm_id')
                         ->as_query,
            },
          },
          {
              prefetch => 'type',
          })
        ->search_related( 'subject', {
            'subject.type_id' => {
                -in => _cvterm_rs( $mrna_feature, 'sequence', 'exon' )
                         ->get_column('cvterm_id')
                         ->as_query,
            },
           },
           {
               prefetch => 'featureloc_features',
           })
        ->search_related( 'featureloc_features', {
            #srcfeature_id => { -not => undef },
	     srcfeature_id => { -not => undef }, locgroup => 0
          },
          {
            prefetch => 'srcfeature',
            order_by => 'fmin',
          },
         );
    return $rs;
}

sub _cvterm_rs {
    my ( $row, $cv, $cvt ) = @_;

    return $row->result_source->schema
               ->resultset('Cv::Cv')
               ->search({ 'me.name' => $cv })
               ->search_related('cvterms', {
                   'cvterms.name' => $cvt,
                 });
}

1;
