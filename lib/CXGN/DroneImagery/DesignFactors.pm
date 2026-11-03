package CXGN::DroneImagery::DesignFactors;

=head1 NAME

CXGN::DroneImagery::DesignFactors - recorded field-design effects and identities

=head1 DESCRIPTION

Resolve declared CRD, RCBD and incomplete-block design effects from recorded
physical metadata, encode literal categories without coercion, and validate
physical/genotype identity before name-keyed output. Accession occurrence
counters never stand in for physical blocks or recorded design groups.

=cut

use strict;
use warnings;
use JSON::PP;

sub kind {
    my ($design) = @_;
    die "Declare studyDesign before fitting drone design effects.\n" unless defined($design) && length($design);
    return 'CRD' if $design =~ /^(?:CRD|completely randomi[sz]ed(?: design)?)$/i;
    return 'RCBD' if $design =~ /RCBD|randomi[sz]ed complete block|augmented/i;
    return 'Incomplete' if $design =~ /alpha|lattice|incomplete/i;
    die "Unsupported studyDesign for drone design effects: $design\n";
}

sub fixed_terms {
    my ($design, $rep, $block) = @_;
    $rep //= 'replicate'; $block //= 'block';
    my $kind = kind($design);
    return '1' if $kind eq 'CRD';
    return $block if $kind eq 'RCBD';
    return "$rep/$block";
}

sub group_key {
    my ($design, $rep, $block, $environment) = @_;
    my $kind = kind($design);
    return undef if $kind eq 'CRD'; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    die "Recorded block metadata is missing; an accession occurrence cannot replace it.\n" unless defined($block) && length($block);
    my @key = (defined($environment) ? "$environment" : (), "$block");
    if ($kind eq 'Incomplete') {
        die "Recorded design replication metadata is missing for an incomplete-block design.\n" unless defined($rep) && length($rep);
        unshift @key, "$rep";
    }
    return JSON::PP->new->canonical->encode(\@key);
}

sub validate_rows {
    my ($design, $rows) = @_;
    for my $row (@$rows) {
        group_key($design,$row->{obsunit_rep},$row->{obsunit_block});
    }
    return 1;
}

# R/YapRI's numeric matrices need integer category codes. The bijection is
# local to this model; literal tags such as 01, 1, 0 and NA stay distinct.

sub category_codes {
    my ($keys) = @_;
    my %seen = map {defined($_) ? ($_ => 1) : ()} @$keys;
    my $index = 0;
    return {map {$_ => ++$index} sort keys %seen};
}

sub numeric_group_code {
    my ($design,$rep,$block,$codes) = @_;
    my $key = group_key($design,$rep,$block);
    return 0 if !defined($key); # Unused metadata column in an unblocked CRD.
    die "Recorded group is missing from the model category map.\n" if !exists($codes->{$key});
    return $codes->{$key};
}

sub cnn_design {
    my ($prediction_type,$designs) = @_;
    return undef unless ($prediction_type // '') eq 'cnn_prediction_mixed_model'; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    die "CNN mixed-model evaluation requires declared trial designs.\n" unless ref($designs) eq 'ARRAY' && @$designs;
    my %unique;
    for my $design (@$designs) {
        kind($design);
        $unique{lc($design)}=1;
    }
    die "CNN mixed-model evaluation requires one supported studyDesign.\n" unless keys(%unique)==1;
    return $designs->[0];
}

sub validate_genotype_names {
    my ($rows,$id_key,$name_key) = @_;
    $id_key //= 'germplasm_stock_id';
    $name_key //= 'germplasm_uniquename';
    my (%name_to_id,%id_to_name);
    for my $row (@$rows) {
        my ($id,$name) = @{$row}{$id_key,$name_key};
        next unless defined($id) && length($id) && $id !~ /^(?:0|NA|--|-|\.|\.\.)$/ && defined($name) && length($name);
        if (exists($name_to_id{$name}) && $name_to_id{$name} ne $id) {
            die "A genotype name maps to multiple known germplasm IDs; this name-keyed analysis cannot represent them separately.\n";
        }
        if (exists($id_to_name{$id}) && $id_to_name{$id} ne $name) {
            die "A known germplasm ID maps to multiple genotype names; this name-keyed analysis requires consistent genotype metadata.\n";
        }
        $name_to_id{$name}=$id;
        $id_to_name{$id}=$name;
    }
    return 1;
}

1;
