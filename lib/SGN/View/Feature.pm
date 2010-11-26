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
/;

sub get_description {
    my ($feature) = @_;
    my $description;

    if ($feature->type->name eq 'gene') {
        my $child = ($feature->child_features)[0];
        ($description) = $child ? map { $_->value } grep { $_->type->name eq 'Note' } $child->featureprops->all : '';
    } else {
        ($description) = map { $_->value } grep { $_->type->name eq 'Note' } $feature->featureprops->all;
    }

    if( $description ) {
        $description =~ s/(\S+)/my $id = $1; CXGN::Tools::Identifiers::link_identifier($id) || $id/ge;
    }

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
        $length += $l->fmax - $l->fmin + 1;
    }
    # Reference features don't have featureloc's, calculate the length
    # directly
    if ($length == 0) {
        $length = $feature->seqlen,
    }
    return ($length,$locations);
}

sub location_list_html {
    my ($feature) = @_;
    my @coords = map { feature_link($_->srcfeature).':'.$_->fmin.'..'.$_->fmax } $feature->featureloc_features->all
        or return '<span class="ghosted">none</span>';
    return @coords;
}
sub location_list {
    my ($feature) = @_;
    return map { $_->srcfeature->name.':'.$_->fmin.'..'.$_->fmax } $feature->featureloc_features->all;
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
            my ($fmin,$fmax) = ($loc->fmin, $loc->fmax);
            push @$data, [
                cvterm_link($f),
                feature_link($f),
                "$fmin..$fmax",
                commify_number($fmax-$fmin+1) . " bp",
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

sub infer_residue {
	my ($feature) = @_;
	my $featureloc = $feature->featureloc_features->single;
	my $length     = $featureloc->fmax - $featureloc->fmin + 1;
	my $srcresidue = $featureloc->srcfeature->residues;
	# substr is 0-based, featureloc's are 1-based
	my $residue    = substr($srcresidue, $featureloc->fmin - 1, $length );
	return $residue;
}

sub mrna_sequence {
    my ($mrna_feature) = @_;
    my @exons        = grep { $_->type->name eq 'exon' } $mrna_feature->child_features;
    my $mrna_residue = join '', map { infer_residue($_) } @exons;
    my $seq = Bio::PrimarySeq->new(
        -id       => $mrna_feature->name,
        -seq      => $mrna_residue,
        -alphabet => 'rna',
    );
    return $seq;
}

1;
