package CXGN::Trial::TrialDesign::ROutput;

use strict;
use warnings;
use Carp qw(croak);
use Encode qw(decode FB_CROAK LEAVE_SRC);
use Exporter 'import';
use R::YapRI::Data::Matrix;

our @EXPORT_OK = qw(read_rbase_utf8);

=head1 NAME

CXGN::Trial::TrialDesign::ROutput - decode UTF-8 at the trial-design R output boundary

=head1 DESCRIPTION

R::YapRI::Data::Matrix::read_rbase reads R's UTF-8 result as byte strings.
Decode only unflagged non-ASCII text in the newly returned matrix, without
changing input matrices, numerical values, algorithm commands or process locale.
Already flagged character strings are preserved literally; this is not a
mojibake repair. Invalid UTF-8 aborts before any public setter is called.

An optional fourth argument maps column names to allowed original identifiers.
Validation rejects unknown or altered output values before any setter. This
cannot restore identifiers changed by the dependency's whitespace parser; CRD
uses the guard for its original stock list. Other algorithms require their own
identity contract before enabling this optional check.

=cut

sub _decoded_array {
    my ($values) = @_;
    croak 'R output matrix accessor must return an array reference'
        unless ref($values) eq 'ARRAY';
    my @decoded;
    my $changed = 0;
    for my $value (@{$values}) {
        if (!defined($value) || ref($value) || utf8::is_utf8($value)) {
            push @decoded, $value;
            next;
        }
        # Inspect a separate scalar so numeric/ASCII originals keep their flags
        # and JSON types. LEAVE_SRC also keeps the inspected byte string intact.
        my $probe = $value;
        if ($probe =~ /[^\x00-\x7f]/) {
            push @decoded, decode('UTF-8', $probe, FB_CROAK | LEAVE_SRC); ## no critic (Bangs::ProhibitBitwiseOperators) # Encode requires both strict-error and source-preservation flag bits.
            $changed = 1;
        }
        else {
            push @decoded, $value;
        }
    }
    return (\@decoded, $changed);
}

sub _validate_expected_columns {
    my ($matrix, $data, $colnames, $expected) = @_;
    return unless defined($expected);
    croak 'R output expected columns must be a hash reference' unless ref($expected) eq 'HASH';
    my $columns = $matrix->get_coln();
    my $rows = $matrix->get_rown();
    for my $name (keys %{$expected}) {
        my $allowed = $expected->{$name};
        croak 'R output expected column values must be an array reference' unless ref($allowed) eq 'ARRAY';
        my %allowed;
        for my $value (@{$allowed}) {
            croak 'R output expected identities must be defined scalar values' if !defined($value) || ref($value);
            my $identity = $value;
            $allowed{$identity} = 1;
        }
        my @indices;
        for my $index (0 .. $#{$colnames}) {
            my $candidate = $colnames->[$index];
            push @indices, $index if defined($candidate) && !ref($candidate) && $candidate eq $name;
        }
        croak 'R output expected identity column is missing or ambiguous' unless @indices == 1;
        for my $row (0 .. $rows - 1) {
            my $value = $data->[$row * $columns + $indices[0]];
            croak 'R output contains a changed or unknown stock identity'
                if !defined($value) || ref($value) || !exists($allowed{$value});
        }
    }
}

sub read_rbase_utf8 {
    my ($rbase, $block, $object, $expected_columns) = @_;
    my $matrix = R::YapRI::Data::Matrix->read_rbase($rbase, $block, $object);
    my ($data, $data_changed) = _decoded_array($matrix->get_data());
    my ($colnames, $columns_changed) = _decoded_array($matrix->get_colnames());
    my ($rownames, $rows_changed) = _decoded_array($matrix->get_rownames());

    _validate_expected_columns($matrix, $data, $colnames, $expected_columns);

    # Validate all text before touching the new result. Use the public API and
    # rebuild data indices only when a data value was actually decoded.
    $matrix->set_colnames($colnames) if $columns_changed;
    $matrix->set_rownames($rownames) if $rows_changed;
    $matrix->set_data($data) if $data_changed;
    return $matrix;
}

1;
