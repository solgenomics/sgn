package SGN::View::Feature;
use strict;
use warnings;

use base 'Exporter';
use Bio::Seq;
use CXGN::Tools::Text qw/commify_number/;
use CXGN::Tools::Identifiers;


our @EXPORT_OK = qw/
    related_stats feature_table
    get_reference feature_link
    infer_residue cvterm_link
    organism_link feature_length
    mrna_sequence
    get_description
    location_list_html
    location_string
    location_string_with_strand
/;

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

sub get_reference {
    my ($feature) = @_;
    my $fl = $feature->featureloc_features->single;
    return unless $fl;
    return $fl->srcfeature;
}

sub feature_length {
    my ($feature) = @_;
    my @locations = $feature->featureloc_features->all;
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
    my ($feature) = @_;
    my @coords = map { location_string($_) } $feature->featureloc_features->all
        or return '<span class="ghosted">none</span>';
    return @coords;
}
sub location_list {
    my ($feature) = @_;
    return map { $_->srcfeature->name.':'.($_->fmin+1).'..'.$_->fmax } $feature->featureloc_features->all;
}

sub related_stats {
    my ($features) = @_;
    my $stats = { };
    my $total = scalar @$features;
    for my $f (@$features) {
            $stats->{cvterm_link($f)}++;
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
            my ($fmin,$fmax) = ($loc->fmin+1, $loc->fmax);
            push @$data, [
                cvterm_link($f),
                feature_link($f),
                "$fmin..$fmax",
                commify_number($fmax-$fmin) . " bp",
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
    return $fl->srcfeature->name . ':'. $fl->fmin . '..' . $fl->fmax;
}

sub feature_link {
    my ($feature) = @_;
    return '<span class="ghosted">null</span>' unless $feature;
    my $name = $feature->name;
    return qq{<a href="/feature/view/name/$name">$name</a>};
}

sub organism_link {
    my ($organism) = @_;
    my $id      = $organism->organism_id;
    my $species = $organism->species;
    return <<LINK;
<span class="species_binomial">
  <a href="/chado/organism.pl?organism_id=$id">$species</a>
</span>
LINK
}

sub cvterm_link {
    my ($feature) = @_;
    my $name = $feature->type->name;
    my $id   = $feature->type->id;
    return qq{<a href="/chado/cvterm.pl?cvterm_id=$id">$name</a>};
}

sub mrna_sequence {
    my ($mrna_feature) = @_;
    my @exon_locations = $mrna_feature
        ->feature_relationship_objects({
            'me.type_id' => {
                -in => _cvterm_rs( $mrna_feature, 'relationship', 'part_of' )
                         ->get_column('cvterm_id')
                         ->as_query,
            },
          })
        ->search_related( 'subject', {
            'subject.type_id' => {
                -in => _cvterm_rs( $mrna_feature, 'sequence', 'exon' )
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
         )
        ->all;

    die 'no exons' unless @exon_locations;
    return unless @exon_locations;

    my $seq = Bio::PrimarySeq->new(
        -id   => $mrna_feature->name,
        -desc => 'spliced cDNA sequence',
        -seq  => join( '', map {
            $_->srcfeature->subseq( $_->fmin+1, $_->fmax ),
         } @exon_locations
        ),
    );

    $seq = $seq->revcom if $exon_locations[0]->strand == -1;

    return $seq;
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
