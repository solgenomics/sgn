=head1 NAME

t/unit/mason/breeders_toolbox/manage_plot_phenotyping.t - the plot phenotyping page renders its trials section

=head1 DESCRIPTION

Renders mason/breeders_toolbox/manage_plot_phenotyping.mas with HTML::Mason.
The page and the trials section it includes (mason/stock/trials.mas) come
from the real component root; the other components the page includes are
replaced by stubs, so no database or Catalyst context is needed.

mason/stock/trials.mas requires a type_name argument. The plot phenotyping
page (/breeders/plot_phenotyping) must pass it, or the page dies with
"no value sent for required parameter 'type_name'".

=cut

use strict;
use warnings;

use Test::More;
use Cwd qw | abs_path |;
use File::Path qw | make_path |;
use File::Temp qw | tempdir |;
use HTML::Mason::Interp;

my $mason_root = abs_path('mason');

my $stub_root = tempdir(CLEANUP => 1);
my $data_dir = tempdir(CLEANUP => 1);

my %stubs = (
    'util/import_javascript.mas' => '',
    'util/import_css.mas' => '',
    'page/page_title.mas' => '',
    'page/info_section.mas' => '<% $m->content %>',
    'stock/download_stock_phenotypes_dialog.mas' => '',
    'stock/traits.mas' => '',
);

foreach my $path (keys %stubs) {
    my $file = "$stub_root/$path";
    (my $dir = $file) =~ s{/[^/]+\z}{};
    make_path($dir);
    open(my $fh, '>', $file) or die "Can't write $file: $!";
    print $fh $stubs{$path};
    close($fh);
}

my $interp = HTML::Mason::Interp->new(
    comp_root => [ [ stubs => $stub_root ], [ main => $mason_root ] ],
    data_dir => $data_dir,
    autohandler_name => '',
    preamble => "use utf8; ",
);

sub render {
    my %args = @_;
    my $output = '';
    eval {
        $interp->make_request(
            comp => '/breeders_toolbox/manage_plot_phenotyping.mas',
            args => [ %args ],
            out_method => \$output,
        )->exec();
    };
    return ($output, $@);
}

my ($output, $error) = render(plot_name => 'test_plot_1', stock_id => 1);

is($error, '', 'plot phenotyping page renders without an error');
like($output, qr/id="trial_summary_data"/, 'the trials section is included');
unlike($output, qr/id="analysis_usage_data"/, 'the accession-only stored analyses table is not shown for a plot');

done_testing();
