package SGN::View::Feature;
use strict;
use warnings;

use base 'Exporter';
use Bio::Seq;
use CXGN::Tools::Text qw/commify_number/;
use CXGN::Tools::Identifiers;


our @EXPORT_OK = qw/
    related_stats feature_table
    feature_link
    infer_residue cvterm_link
    organism_link feature_length
    mrna_and_protein_sequence
    get_description
    location_list_html
    location_string
    location_string_with_strand
    type_name
/;

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

sub get_description {
    my ($feature) = @_;

    my $desc_types =
        $feature->result_source->schema
                ->resultset('Cv::Cvterm')
                ->search({ name => [ 'Note', 'functional_description', 'Description' ] })
                ->get_column('cvterm_id')
                ->as_query;
    my $description =
        $feature->search_related('featureprops', {
            type_id => { -in => $desc_types },
        })->get_column('value')
          ->first;

    return unless $description;

    $description =~ s/(\S+)/my $id = $1; CXGN::Tools::Identifiers::link_identifier($id) || $id/ge;

    return $description;
}

sub feature_length {
    my ($feature, $featurelocs) = @_;
    my @locations = $featurelocs ? $featurelocs->all : $feature->featureloc_features->all;
    my $locations = scalar @locations;
    my $length = 0;
    for my $l (@locations) {
        $length += $l->fmax - $l->fmin;
    }
    # Reference features don't have featureloc's, calculate the length
    # directly
    if ($length == 0) {
        $length = $feature->seqlen,
    }
    return ($length,$locations);
}

sub location_string {
    my ( $loc ) = @_;
    return feature_link($loc->srcfeature).':'.($loc->fmin+1).'..'.$loc->fmax;
}

sub location_string_with_strand {
    my ( $loc ) = @_;
    return location_string( $loc ).( $loc->strand == -1 ? '(rev)' : '' )
}

sub location_list_html {
    my ($feature, $featurelocs) = @_;
    my @coords = map { location_string($_) }
        ( $featurelocs ? $featurelocs->all
                       : $feature->featureloc_features->all)
        or return '<span class="ghosted">none</span>';
    return @coords;
}
sub location_list {
    my ($feature, $featurelocs) = @_;
    return map { $_->srcfeature->name . ':' . ($_->fmin+1) . '..' . $_->fmax }
        ( $featurelocs ? $featurelocs->all
                       : $feature->featureloc_features->all );
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
    my ($features) = @_;
    my $data = [];
    for my $f (@$features) {
        my @locations = $f->featureloc_features->all;

        # Add a row for every featureloc
        for my $loc (@locations) {
            my ($start,$end) = ($loc->fmin+1, $loc->fmax);
            push @$data, [
                cvterm_link($f->type),
                feature_link($f),
                "$start..$end",
                commify_number( $end-$start+1 ) . " bp",
                $loc->strand == 1 ? '+' : '-',
                $loc->phase || '<span class="ghosted">n/a</span>',
            ];
        }
    }
    return $data;
}

sub _feature_search_string {
    my ($feature) = @_;
    my ($fl) = $feature->featureloc_features;
    return '' unless $fl;
    return $fl->srcfeature->name . ':'. ($fl->fmin+1) . '..' . $fl->fmax;
}


### XXX TODO: A lot of these _link and sequence functions need to be
### moved to controller code.

sub feature_link {
    my ($feature) = @_;
    return '<span class="ghosted">null</span>' unless $feature;
    my $id   = $feature->feature_id;
    my $name = $feature->name;
    return qq{<a href="/feature/view/id/$id">$name</a>};
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
    return qq{<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>};
}

sub mrna_and_protein_sequence {
    my ($mrna_feature) = @_;
    my @exon_locations = _exon_rs( $mrna_feature )->all
        or return;

    my $mrna_seq = Bio::PrimarySeq->new(
        -id   => $mrna_feature->name,
        -desc => 'spliced cDNA sequence',
        -seq  => join( '', map {
            $_->srcfeature->subseq( $_->fmin+1, $_->fmax ),
         } @exon_locations
        ),
    );

    my $peptide_loc = _peptides_rs( $mrna_feature )->first
        or return ( $mrna_seq, undef );

    my $trim_fmin = $peptide_loc->fmin         -  $exon_locations[0]->fmin;
    my $trim_fmax = $exon_locations[-1]->fmax  -  $peptide_loc->fmax;
    if( $trim_fmin || $trim_fmax ) {
        $mrna_seq = $mrna_seq->trunc( 1+$trim_fmin, $mrna_seq->length - $trim_fmax );
    }

    $mrna_seq = $mrna_seq->revcom if $exon_locations[0]->strand == -1;

    my $protein_seq = Bio::PrimarySeq->new(
        -id   => $mrna_feature->name,
        -desc => 'protein sequence',
        -seq  => $mrna_seq->seq,
       );
    $protein_seq = $protein_seq->translate;

    return ( $mrna_seq, $protein_seq );
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
        ->search_related( 'featureloc_features', {
            srcfeature_id => { -not => undef },
          },
          { prefetch => 'srcfeature',
            order_by => 'fmin',
          },
         );
}

sub _exon_rs {
    my ( $mrna_feature ) = @_;

    $mrna_feature
        ->feature_relationship_objects({
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
            srcfeature_id => { -not => undef },
          },
          {
            prefetch => 'srcfeature',
            order_by => 'fmin',
          },
         )
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
