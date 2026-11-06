use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;
use File::Temp qw(tempdir);
use File::Slurp qw(read_file write_file);
use JSON qw(encode_json decode_json);
use SGN::Controller::solGS::Anova;
use SGN::Controller::solGS::Utils;
use SGN::Controller::solGS::solGS;

# Exercise the public phenotype-data action with real temporary TSV input.
# Only DB trait lookup and query execution are replaced by synthetic services.
my $directory = tempdir(CLEANUP => 1);
my $controller = SGN::Controller::solGS::Anova->new;
my $case_number = 0;
for my $case (
    {name => 'numeric nonfinal column', values => ['0', '-2.5', '+3', '.25']},
    {name => 'numeric final column', last => 1, values => ['0', '2', '3.5']},
    {name => 'scientific notation', values => ['1e-3', '-2.5E+2', '0']},
    {name => 'R missing markers', values => ['1', 'NA', '.', '..', '-', ' ', '', 'NaN']},
    {name => 'actual text', values => ['1', 'red', '3'], error => qr/not all numeric/},
    {name => 'numeric prefix is not a number', values => ['1', '12cm', '3'], error => qr/not all numeric/},
    {name => 'missing trait column', missing_column => 1, values => ['1', '2'], error => qr/selected trait.*not.*phenotype/i},
    {name => 'all values missing', values => ['NA', '.', '..', '-', ''], error => qr/no numeric observations/i},
    {name => 'header only', values => [], error => qr/no numeric observations/i},
    {name => 'fresh numeric file', fresh => 1, last => 1, values => ['0', '2', '3.5']},
    {name => 'fresh text file', fresh => 1, values => ['1', 'red', '3'], error => qr/not all numeric/},
    {name => 'path with spaces', spaced_path => 1, values => ['0', '2', '3']},
    {name => 'CRLF final header', last => 1, crlf => 1, values => ['0', '2', '3']},
    {name => 'composed trait', trait => 'plant height|CO_334:0000001||day 43|TIME:0000043', last => 1, values => ['0', '2', '3']},
    {name => 'duplicate base acronym', trait => 'dry matter content', other => 'disease mean count', last => 1, abbr => 'DMC.2', values => ['0', '2', '3']},
    {name => 'literal acronym metacharacter', trait => 'A+B', last => 1, values => ['0', '2', '3']},
    {name => 'nonfinite measurement', values => ['1', 'Inf', '3'], error => qr/not all numeric/},
    {name => 'incomplete cached row', values => ['1', '2'], short_row => 1, error => qr/inconsistent columns/},
    {name => 'ambiguous trait mapping', values => ['1', '2'], ambiguous => 1, error => qr/ambiguous phenotype column/},
    {name => 'failed query cannot appear successful', fresh => 1, query_error => 1, values => ['1', '2'], error => qr/error querying/},
    {name => 'query without data', fresh => 1, no_data => 1, values => ['1', '2'], error => qr/no phenotype data/},
    {name => 'missing cached trait mapping', values => ['1', '2'], map_missing => 1, error => qr/selected trait.*no mapping/i},
    {name => 'empty cached trait mapping', values => ['1', '2'], map_empty => 1, error => qr/selected trait.*no mapping/i},
) {
    subtest $case->{name} => sub {
        my $trait = $case->{trait} || 'height cm';
        my $other = $case->{other} || 'neighbor';
        my $clean_trait = SGN::Controller::solGS::Utils->clean_traits($trait);
        my $abbr = $case->{abbr} || SGN::Controller::solGS::Utils->abbreviate_term($clean_trait);
        my @headers = $case->{last} ? ('germplasmName', $other, $trait) : ('germplasmName', $trait, $other);
        my $header = SGN::Controller::solGS::solGS->format_phenotype_dataset_headers(
            join("\t", @headers), ['germplasmName']);
        if ($case->{missing_column}) { $header =~ s/\Q$abbr\E/absent_trait/; }
        my $newline = $case->{crlf} ? "\r\n" : "\n";
        my $content = $header.$newline;
        for my $i (0 .. $#{$case->{values}}) {
            my $value = $case->{values}[$i];
            my @row = $case->{last} ? ('G'.$i, 'neighbor text', $value) : ('G'.$i, $value, 'neighbor text');
            pop @row if $case->{short_row} && $i == 1;
            $content .= join("\t", @row).$newline;
        }
        my $file = "$directory/phenotype_data_".(++$case_number).($case->{spaced_path} ? ' with spaces' : '').'.txt';
        write_file($file, {binmode => ':utf8'}, $content) unless $case->{fresh};

        my $c = Test::MockObject->new;
        $c->{stash} = {trial_id => 101, trait_id => 201};
        $c->mock(stash => sub { $c->{stash} });
        $c->mock(error => sub { $case->{query_error} ? ['synthetic query failure'] : [] });
        my $request = Test::MockObject->new;
        $request->mock(param => sub { encode_json({trial_id => 101, trait_id => 201}) });
        $c->mock(req => sub { $request });
        my $utils = Test::MockObject->new;
        $utils->mock(stash_json_args => sub { return });
        $utils->mock(clean_traits => sub { SGN::Controller::solGS::Utils->clean_traits($_[1]) });
        $utils->mock(abbreviate_term => sub { SGN::Controller::solGS::Utils->abbreviate_term($_[1]) });
        my $traits = Test::MockObject->new;
        $traits->mock(get_trait_details => sub {
            $c->stash->{trait_name} = $trait;
            $c->stash->{trait_id} = 201;
            $c->stash->{trait_abbr} = SGN::Controller::solGS::Utils->abbreviate_term($trait);
        });
        $traits->mock(get_all_traits => sub { return });
        $traits->mock(get_acronym_pairs => sub {
            return [] if $case->{map_empty};
            return [['unrelated', 'another trait']] if $case->{map_missing};
            return $case->{ambiguous} ? [[$abbr, "$clean_trait\n"], [$abbr.".2", "$clean_trait\n"]] : [[$abbr, "$clean_trait\n"]];
        });
        my $files = Test::MockObject->new;
        $files->mock(phenotype_file_name => sub { $c->stash->{phenotype_file_name} = $file; return $file; });
        $files->mock(all_traits_file => sub { return });
        $c->mock(controller => sub {
            my $name = lc($_[1]);
            return $utils if $name eq 'solgs::utils';
            return $traits if $name eq 'solgs::trait';
            return $files if $name eq 'solgs::files';
            die "Unexpected service $name";
        });
        my $query = Test::MockModule->new('SGN::Controller::solGS::Anova');
        $query->mock(create_anova_phenodata_file => sub {
            write_file($file, {binmode => ':utf8'}, $content) unless $case->{no_data};
            return $file;
        });
        my $ok = eval { $controller->anova_phenotype_data($c); 1 };
        ok($ok, 'action completes without an exception') or diag $@;
        my $response = $c->stash->{rest} || {};
        if ($case->{error}) {
            like($response->{Error} || '', $case->{error}, 'action gives the appropriate data error');
            ok(!$response->{success}, 'invalid input is not reported as successful');
            like($response->{Error}, qr/row 3/, 'the first invalid record is identified')
                if $case->{name} =~ /actual text|numeric prefix|nonfinite/;
        }
        else {
            ok(!$response->{Error}, 'valid numeric observations are accepted') or diag $response->{Error};
            is($response->{success}, 'Success.', 'fresh and cached input share the success contract');
            my $selected = eval { decode_json($response->{traits_abbrs} || '{}') } || {};
            is($selected->{trait_abbr}, $abbr, 'returned trait abbreviation matches the actual data header');
            my $analyzed;
            $query->mock(check_anova_output => sub { 0 });
            $query->mock(run_anova => sub { $analyzed = $c->stash->{trait_abbr}; return });
            $query->mock(prepare_response => sub { return });
            $controller->anova_analyis($c);
            is($analyzed, $abbr, 'analysis job receives the same resolved trait abbreviation');
        }
        if ($case->{no_data}) {
            ok(!-s $file, 'an unavailable query result is not fabricated');
        }
        else {
            is(read_file($file, {binmode => ':utf8'}), $content, 'validation does not rewrite phenotype observations');
        }
    };
}

done_testing();
