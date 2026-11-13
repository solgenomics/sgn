use strict;
use warnings;

# The heritability scripts fit the block number as a factor. A trait observed in
# one block only must still get a result, and must not stop the other traits.

use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use IPC::Run qw(run);

my ($rscript) = grep { -x $_ } map { File::Spec->catfile($_, 'Rscript') } File::Spec->path;
plan skip_all => 'Rscript is not installed' unless $rscript;
my $directory = tempdir('HeritabilityBlocksXXXXXX', TMPDIR => 1, CLEANUP => 1);

# six accessions with three plots each: two in block 1, one in block 2;
# trait b was observed in block 1 only
my @rows;
my @noise = (0.3, -0.2, 0.1, -0.4, 0.2, 0.0, -0.1, 0.4, -0.3, 0.1, 0.0, -0.2, 0.2, -0.1, 0.3, -0.3, 0.1, 0.2);
my $n = 0;
for my $accession (1 .. 6) {
    for my $plot ([1, 1], [1, 2], [2, 3]) {
        my ($block, $replicate) = @$plot;
        my $a = 10 + 2 * $accession + $block + $noise[$n];
        my $b = $block == 1 ? 20 + 3 * $accession + $noise[17 - $n] : 'NA';
        push @rows, [2025, 'test_location', "G$accession", $block, $replicate, $a, $b];
        $n++;
    }
}

subtest 'h2_blup_rscript.R' => sub {
    my $pheno = "$directory/blup_pheno.txt";
    my %out = map { $_ => "$directory/blup_$_" } qw(h2.json h2.csv error.txt);
    write_file($pheno, join("\n",
        join("\t", qw(studyYear locationName germplasmName blockNumber replicate),
            'trait a|CO_000:0000001', 'trait b|CO_000:0000002'),
        map { join("\t", @$_) } @rows)."\n");
    my ($stdout, $stderr);
    run([$rscript, 'R/heritability/h2_blup_rscript.R', $pheno, 'trait.a', @out{qw(h2.json h2.csv error.txt)}],
        '<', \undef, '>', \$stdout, '2>', \$stderr);
    ok(!-s $out{'error.txt'}, 'no error is reported')
        or diag(read_file($out{'error.txt'}));
    my $csv = -e $out{'h2.csv'} ? read_file($out{'h2.csv'}) : '';
    like($csv, qr/"trait a"/, 'the trait observed in two blocks has a result') or diag($stderr);
    like($csv, qr/"trait b"/, 'the trait observed in one block has a result') or diag($stderr);
};

subtest 'h2_rscript.R' => sub {
    my @packages = qw(ltm rjson data.table phenoAnalysis dplyr na.tools lmerTest tibble);
    my $check = 'quit(status = !all(sapply(c('.join(',', map { "'$_'" } @packages).'), requireNamespace, quietly = TRUE)))';
    plan skip_all => 'the R packages of h2_rscript.R are not installed'
        unless run([$rscript, '-e', $check], '<', \undef, '>', \my $out, '2>', \my $err);
    my $pheno = "$directory/phenotype_data_h2.txt";
    my $metadata = "$directory/h2_metadata.txt";
    my $table = "$directory/h2_coefficients_table.txt";
    my $json = "$directory/h2_coefficients_json.txt";
    my $inputs = "$directory/h2_input_files.txt";
    my $outputs = "$directory/h2_output_files.txt";
    write_file($pheno, join("\n",
        join("\t", qw(studyYear locationName germplasmName blockNumber replicate trait_a trait_b)),
        map { join("\t", @$_) } @rows)."\n");
    write_file($metadata, join("\n", qw(studyYear locationName germplasmName blockNumber replicate))."\n");
    write_file($inputs, "$pheno\n$metadata\n");
    write_file($outputs, "$table\n$json\n");
    my ($stdout, $stderr);
    my $ok = run([$rscript, 'R/heritability/h2_rscript.R', $inputs, $outputs],
        '<', \undef, '>', \$stdout, '2>', \$stderr);
    ok($ok, 'the script completes') or diag($stderr);
    my @lines = -e $table ? split(/\n/, read_file($table)) : ();
    my %traits = map { (split /\t/)[0] => 1 } @lines[1 .. $#lines];
    ok($traits{trait_a}, 'the trait observed in two blocks has a result') or diag($stderr);
    ok($traits{trait_b}, 'the trait observed in one block has a result') or diag($stderr);
};

done_testing();
