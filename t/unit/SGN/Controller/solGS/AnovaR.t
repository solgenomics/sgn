use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use Text::CSV;
use IPC::Run qw(run);

my ($rscript) = grep { -x $_ } map { File::Spec->catfile($_, 'Rscript') } File::Spec->path;
plan skip_all => 'Rscript is not installed' unless $rscript;
my $directory = tempdir('AnovaRXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $script = File::Spec->rel2abs('R/solGS/anova.r');
my @metadata = qw(germplasmName germplasmDbId observationUnitName studyName studyYear studyDesign blockNumber locationName replicate);
my @values = ([0, '.6', '-6E-1', 1], [2.1, 2.4, 1.5, 3], [3.9, 4.5, 3.6, 5]);

for my $case ('balanced', 'missing') {
    subtest $case => sub {
        my $file = "$directory/phenotype_data_$case.txt";
        my $traits = "$directory/selected_traits_$case.txt";
        my $metadata = "$directory/phenotype_metadata_$case.txt";
        my $input = "$directory/anova_input_files_$case.txt";
        my $output = "$directory/anova_output_files_$case.txt";
        my %outputs = map { $_ => "$directory/${_}_$case.txt" }
            qw(anova_table_html anova_table_txt anova_model adj_means anova_diagnostics anova_error);
        my $content = join("\t", @metadata, 'SYN')."\n";
        my $observations = 0;
        for my $genotype (0 .. 2) {
            for my $replicate (1 .. 4) {
                my $value = $values[$genotype][$replicate - 1];
                if ($case eq 'missing') {
                    $value = '.' if $genotype == 0 && $replicate == 4;
                    $value = '-' if $genotype == 1 && $replicate == 1;
                    $value = '..' if $genotype == 1 && $replicate == 2;
                    $value = 'NA' if $genotype == 2 && $replicate == 3;
                    $value = ' ' if $genotype == 2 && $replicate == 1;
                }
                $observations++ unless $value =~ /\A(?:NA|\.|\.\.|-| )\z/;
                $content .= join("\t", chr(65 + $genotype), $genotype + 1,
                    'synthetic_'.($genotype * 4 + $replicate), 'Synthetic ANOVA',
                    2030, 'CRD', $replicate, 'Synthetic location', $replicate, $value)."\n";
            }
        }
        write_file($file, $content);
        write_file($traits, 'SYN');
        write_file($metadata, join("\t", @metadata));
        write_file($input, join("\t", $file, $traits, $metadata));
        write_file($output, join("\t", map { $outputs{$_} }
            qw(anova_table_html anova_table_txt anova_model adj_means anova_diagnostics anova_error)));

        my ($stdout, $stderr);
        my $ran = eval { run([$rscript, $script, $input, $output], '>', \$stdout, '2>', \$stderr) };
        ok($ran, 'the actual ANOVA R script completes') or diag($stderr || $@);
        ok(-s $outputs{anova_table_html}, 'ANOVA table is produced');
        ok(-s $outputs{adj_means}, 'adjusted means are produced');
        ok(!-s $outputs{anova_error}, 'no analysis error is reported');
        is(read_file($file), $content, 'analysis does not rewrite source observations');
        my $model = -s $outputs{anova_model} ? read_file($outputs{anova_model}) : '';
        like($model, qr/Number of obs:\s*\Q$observations\E\b/,
            'model uses observed values and omits missing markers without filling them');
        if ($case eq 'balanced' && -s $outputs{adj_means}) {
            my $parser = Text::CSV->new({sep_char => "\t", binary => 1});
            open(my $means, '<', $outputs{adj_means}) or die $!;
            my $headers = $parser->getline($means);
            my ($mean_column) = grep { $headers->[$_] =~ /emmean|BLUE|adjusted.*mean/i } 0 .. $#$headers;
            ok(defined($mean_column), 'adjusted-mean column is identified') or diag explain($headers);
            my %expected = (A => .25, B => 2.25, C => 4.25);
            while (my $row = $parser->getline($means)) {
                next unless exists($expected{$row->[0]}) && defined($mean_column);
                cmp_ok(abs($row->[$mean_column] - $expected{$row->[0]}), '<', 0.000001,
                    "balanced synthetic genotype $row->[0] has the expected adjusted mean");
                delete $expected{$row->[0]};
            }
            close $means;
            is(scalar keys %expected, 0, 'all three genotypes are represented');
        }
    };
}

done_testing();
