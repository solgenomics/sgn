use strict;
use warnings;

use Test::More;
use Test::MockObject;
use File::Temp qw(tempdir);
use File::Spec;
use File::Slurp qw(read_file write_file);
use SGN::Controller::solGS::Anova;
use SGN::Controller::solGS::Files;

# The ANOVA response offers the means comparison only when the R job wrote it
# (phenoAnalysis with compareMeans). The R job itself does not run here.
my $directory = tempdir('AnovaMeansXXXXXX', TMPDIR => 1, CLEANUP => 1);
my $files = SGN::Controller::solGS::Files->new;
my $anova = SGN::Controller::solGS::Anova->new;

sub context {
    my ($trait_id) = @_;
    my $c = Test::MockObject->new;
    $c->{stash} = {
        trial_id  => 101,
        trait_id  => $trait_id,
        anova_dir => File::Spec->catdir($directory, 'anova', 'trials'),
    };
    $c->mock(stash => sub { $c->{stash} });
    $c->mock(controller => sub { $files });
    $c->mock(config => sub { { tempfiles_subdir => 'static/tempfiles', basepath => $directory } });
    return $c;
}

sub write_anova_outputs {
    my ($c) = @_;
    $anova->anova_table_file($c);
    write_file($c->stash->{anova_table_html_file}, '<table>anova</table>');
    write_file($c->stash->{anova_table_txt_file}, 'anova');
    $anova->anova_model_file($c);
    write_file($c->stash->{anova_model_file}, 'model');
    $anova->adj_means_file($c);
    write_file($c->stash->{adj_means_file}, "germplasmName\tGY\n");
    $anova->anova_diagnostics_file($c);
    write_file($c->stash->{anova_diagnostics_file}, 'png');
}

subtest 'the R job lists the means comparison files as outputs' => sub {
    my $c = context(201);
    $anova->anova_trial_temp_dir($c, 101);
    $anova->anova_output_files($c);
    my @outputs = split /\t/, read_file($c->stash->{anova_output_files});
    is(scalar(grep { /means_comparison_table_101_201/ } @outputs), 1, 'the table file');
    is(scalar(grep { /means_comparison_summary_101_201/ } @outputs), 1, 'the summary file');
};

subtest 'a written comparison is in the response' => sub {
    my $c = context(202);
    write_anova_outputs($c);
    $anova->means_comparison_files($c);
    write_file($c->stash->{means_comparison_table_file}, "germplasmName\tGY_mean\tSE\tgroup\nCP-8\t15.9\t0.92\ta\n");
    write_file($c->stash->{means_comparison_summary_file}, "Fisher's LSD (0.05): 1.252, df = 21, F test p = 1.31e-06.");

    $anova->prepare_response($c);
    my $rest = $c->stash->{rest};
    like($rest->{means_comparison_file}, qr{^static/tempfiles/anova/trials/101/means_comparison_table_101_202},
        'the table is offered for download');
    ok(-s File::Spec->catfile($directory, $rest->{means_comparison_file}), 'the download file is there');
    is($rest->{means_comparison_summary}, "Fisher's LSD (0.05): 1.252, df = 21, F test p = 1.31e-06.",
        'the LSD line is shown');
    ok($rest->{adj_means_file}, 'the other downloads stay');
};

subtest 'without a comparison the response has no link' => sub {
    my $c = context(203);
    write_anova_outputs($c);

    $anova->prepare_response($c);
    my $rest = $c->stash->{rest};
    ok(!exists $rest->{means_comparison_file}, 'no download link');
    ok(!exists $rest->{means_comparison_summary}, 'no LSD line');
    ok($rest->{anova_table_html_file}, 'the ANOVA table is still given');
};

done_testing();
