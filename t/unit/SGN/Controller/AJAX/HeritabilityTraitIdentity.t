use strict;
use warnings;
use Test::More;
use SGN::Controller::AJAX::Heritability;

# The real ID-to-extended-name lookup owns the header contract; this stub
# isolates identity selection from database fixture state.
my %declared = (
    70741 => 'dry matter content percentage|CO_334:0000092',
    70742 => q{root/weight (farmer's choice)|CO_334:0000012},
    70743 => 'height|CO_334:0000013 + day 30|COMP:0000001',
);
my @traits = (
    [70741, 'dry matter content percentage'],
    [70742, q{root/weight (farmer's choice)}],
    [70743, 'height|CO_334:0000013 + day 30'],
);
my %canonical_names = map { $_->[0] => $_->[1] } @traits;
my @derived_traits = map { [$_->[0], $declared{$_->[0]}] } @traits;
{
    package HeritabilityIdentityCvterm; ## no critic (Modules::RequireFilenameMatchesPackage) -- This local test double exposes the owning Cvterm name accessor.
    sub name { return $_[0]->{name} }
}
my @headers = ('studyDbId', 'germplasmName', values %declared);
my @lookup;
{
    no warnings 'redefine';
    local *CXGN::Cvterm::new = sub {
        my ($class, $args) = @_;
        return bless { name => $canonical_names{$args->{cvterm_id}} }, 'HeritabilityIdentityCvterm';
    };
    local *SGN::Model::Cvterm::get_trait_from_cvterm_id = sub {
        my ($schema, $id, $format) = @_;
        push @lookup, [$schema, $id, $format];
        return $declared{$id};
    };
    my $resolve = \&SGN::Controller::AJAX::Heritability::_resolve_trait_header;
    is($resolve->('schema', \@traits, \@headers, '70741'), $declared{70741},
        'the numeric HTTP option ID resolves to its owning extended matrix header');
    is_deeply($lookup[-1], ['schema', 70741, 'extended'],
        'selection uses the matrix owning helper and extended format');
    for my $dataset_traits (\@traits, \@derived_traits) {
        for my $trait (@traits) {
            for my $selected (@$trait) {
                is($resolve->('schema', $dataset_traits, \@headers, $selected), $declared{$trait->[0]},
                    'ID and canonical browser name resolve for explicit and derived dataset labels');
            }
        }
    }
    my @cases = (
        [undef, \@traits, \@headers, qr/required/],
        ['99999', \@traits, \@headers, qr/not found in the dataset/],
        ['dry.matter.content.percentage', \@traits, \@headers, qr/not found in the dataset/],
        ['70741', [@derived_traits, [9, 'unrelated extended label|OTHER:9']], \@headers, qr/ambiguous in the dataset/, '70741'],
        ['dry matter content percentage', [@derived_traits, [9, 'unrelated extended label|OTHER:9']], \@headers, qr/ambiguous in the dataset/, 'dry matter content percentage'],
        ['70741', \@traits, ['studyDbId'], qr/header was not found/],
        ['70741', \@traits, [@headers, $declared{70741}], qr/header is ambiguous/],
        ['9', [[9, 'not declared']], \@headers, qr/no declared phenotype header/],
    );
    for my $case (@cases) {
        my ($selected, $traits, $headers, $message, $extra_name) = @$case;
        local $canonical_names{9} = $extra_name;
        my $ok = eval { $resolve->('schema', $traits, $headers, $selected); 1 };
        my $error = $@;
        ok(!$ok, 'unknown, missing or ambiguous identity does not choose a trait');
        like($error, $message, 'identity error explains the failed contract');
    }
    is($resolve->('schema', [@traits, $traits[0]], \@headers, 70741), $declared{70741},
        'duplicate references to the same ID are not a second identity');
}

# Exercise the actual shell transport, not a mirror of the escaping rule.
for my $header (values %declared) {
    my $quoted = SGN::Controller::AJAX::Heritability::_shell_quote($header);
    open my $pipe, '-|', '/bin/sh', '-c', "printf '%s\\n' $quoted" or die $!;
    my @arguments = <$pipe>;
    close $pipe;
    chomp @arguments;
    is_deeply(\@arguments, [$header], 'raw owning header reaches R as one unchanged argument');
}
done_testing;
