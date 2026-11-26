# Fisher's LSD of the BLUEs in the mixed models tool: the lme4 script writes
# the comparison when phenoAnalysis has compareMeans, and the page shows the
# LSD as a table with one row per trait.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use IPC::Run qw(run);
use Scalar::Util qw(looks_like_number);
use SGN::Controller::AJAX::MixedModels;

my $directory = tempdir('MixedModelsLSDXXXXXX', TMPDIR => 1, CLEANUP => 1);

subtest 'the LSD table has one row per trait' => sub {
    my $file = "$directory/table.meansComparison";
    write_file($file, join("\n",
        join("\t", 'statistic', 'fresh root weight|CO_334:0000012', 'height <cm>'),
        join("\t", 'alpha',    '0.05',     ''),
        join("\t", 'LSD',      '1.252',    ''),
        join("\t", 'LSD_min',  '1.1',      ''),
        join("\t", 'LSD_max',  '1.4',      ''),
        join("\t", 'df',       '21',       ''),
        join("\t", 'F_test_p', '1.31e-06', ''),
        join("\t", 'note',     '',         'At least two levels of germplasmName with a mean are needed to compare means.'),
    )."\n");

    my $html = SGN::Controller::AJAX::MixedModels->means_comparison_html($file);
    like($html, qr{<tr><td>fresh root weight\|CO_334:0000012</td><td>1\.252</td><td>1\.1</td><td>1\.4</td><td>21</td><td>1\.31e-06</td><td>0\.05</td><td></td></tr>},
        'a trait with its LSD, df, p value and alpha');
    like($html, qr{<tr><td>height &lt;cm&gt;</td>(?:<td></td>){6}<td>At least two levels}, 'a trait without an LSD has the note; the name is escaped');
};

subtest 'the letter groups table escapes the names' => sub {
    my $file = "$directory/table.meansGroups";
    write_file($file, join("\n", join("\t", 'germplasmName', 'GY', 'height <cm>'), join("\t", 'A <b>1</b>', 'a', ''), join("\t", 'B', 'b', ''))."\n");

    my $html = SGN::Controller::AJAX::MixedModels->means_groups_html($file);
    like($html, qr{<tr><th>accession name</th><th>GY</th><th>height &lt;cm&gt;</th></tr>}, 'the header');
    like($html, qr{<tr><td>A &lt;b&gt;1&lt;/b&gt;</td><td>a</td><td></td></tr><tr><td>B</td><td>b</td><td></td></tr>}, 'a row per accession');
};

my ($rscript) = grep { -x $_ } map { File::Spec->catfile($_, 'Rscript') } File::Spec->path;

SKIP: {
    skip 'Rscript is not installed', 1 unless $rscript;

    subtest 'the lme4 script with accessions as a fixed factor' => sub {
        # RCBD: accessions A to F in 4 blocks, 2 units apart
        my @noise = (0.1, -0.2, 0.3, 0, -0.1, 0.2, -0.3, 0.1, 0, 0.2, -0.1, -0.2);
        my @block = (0, 1.5, -1, 2);
        my $data = "$directory/phenotype.txt";
        my $content = join("\t", qw(studyYear germplasmName blockNumber replicate GY))."\n";
        my $n = 0;
        for my $accession (0 .. 5) {
            for my $b (0 .. 3) {
                my $value = 10 + 2 * $accession + $block[$b] + $noise[$n++ % @noise];
                $content .= join("\t", 2025, chr(65 + $accession), $b + 1, $b + 1, $value)."\n";
            }
        }
        write_file($data, $content);
        my $params = "$directory/phenotype.txt.params";
        write_file($params, join("\n",
            'dependent_variables <- c("GY")',
            'random_factors <- c("blockNumber")',
            'fixed_factors <- c("germplasmName")',
            'model <- "germplasmName + (1|blockNumber)"')."\n");

        my ($stdout, $stderr);
        my $ran = run([$rscript, File::Spec->rel2abs('R/mixed_models.R'), qq{datafile="$data"}, qq{paramfile="$params"}],
            '>', \$stdout, '2>', \$stderr);
        ok($ran, 'the R script completes') or diag($stderr);
        ok(-s "$data.adjustedBLUEs", 'it writes the BLUEs');

        my $compare_means = run([$rscript, '-e',
            'quit(status = as.integer(!(requireNamespace("phenoAnalysis", quietly=TRUE) && "compareMeans" %in% getNamespaceExports("phenoAnalysis"))))'],
            '>', \my $out, '2>', \my $err);

        if (!$compare_means) {
            ok(!-e "$data.meansComparison" && !-e "$data.meansGroups", 'without compareMeans it writes no comparison');
            return;
        }

        my %comparison = map { chomp; my ($statistic, $value) = split /\t/, $_, -1; ($statistic => $value) }
            read_file("$data.meansComparison");
        is($comparison{statistic}, 'GY', 'the comparison has a column for the trait');
        is($comparison{alpha}, '0.05', 'alpha');
        cmp_ok($comparison{LSD}, '>', 0, 'an LSD');
        cmp_ok($comparison{LSD}, '<', 2, 'smaller than the difference of the accessions');
        is($comparison{df}, '15', 'the residual df of an RCBD with 6 accessions in 4 blocks');
        (my $p = $comparison{F_test_p}) =~ s/^<\s*//;
        ok(looks_like_number($p), 'a p value');
        cmp_ok($p, '<', 0.05, 'the F test is significant');
        is($comparison{note}, 'NA', 'no note');

        my @groups = read_file("$data.meansGroups");
        chomp(@groups);
        is(shift(@groups), "germplasmName\tGY", 'the groups have a column for the trait');
        is_deeply({ map { split /\t/ } @groups }, { A => 'f', B => 'e', C => 'd', D => 'c', E => 'b', F => 'a' },
            'each accession has its own letter, the largest mean a');
    };
}

done_testing();
