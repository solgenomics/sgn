use strict;
use warnings;

use Test::More;
use Cwd qw(abs_path);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use HTML::Mason::Interp;

{
    package TrialDetailsTestContext;
    sub get_conf { return 0; }
}

my $stub_root = tempdir(CLEANUP => 1);
my %stubs = (
    'util/import_javascript.mas' => '',
    'util/barcode.mas' => '<div id="test_trial_barcode"></div>',
    'page/info_section.mas' => '<% $m->content %>',
);
for my $path (keys %stubs) {
    my $file = "$stub_root/$path";
    (my $dir = $file) =~ s{/[^/]+\z}{};
    make_path($dir);
    open(my $fh, '>', $file) or die "Can't write $file: $!";
    print $fh $stubs{$path};
    close($fh);
}

my $interp = HTML::Mason::Interp->new(
    comp_root => [[stubs => $stub_root], [main => abs_path('mason')]],
    data_dir => tempdir(CLEANUP => 1),
    autohandler_name => '',
    allow_globals => ['$c'],
);
$HTML::Mason::Commands::c = bless {}, 'TrialDetailsTestContext';

sub render {
    my ($component, %args) = @_;
    my %defaults = (
        info_section_id => 'trial_details', trial_id => 137, trial_name => 'Test Trial',
        breeding_program => 1, breeding_program_name => 'Test Program', breeding_program_id => 1,
        location => 23, location_name => 'Test Location', country_name => 'USA', year => 2017,
        trial_type => '', trial_type_id => undef, planting_date => undef,
        show_transplanting_date => 0, transplanting_date => undef, harvest_date => undef,
        trial_description => '', field_size => undef, plot_width => 1, plot_length => 2,
        field_trial_is_planned_to_be_genotyped => 'no', field_trial_is_planned_to_cross => 'no',
    );
    my $output = '';
    $interp->make_request(
        comp => $component,
        args => [%defaults, %args],
        out_method => \$output,
    )->exec();
    return $output;
}

for my $field_enabled (0, 1) {
    for my $date_enabled (0, 1) {
        my %args = (
            show_field_number => $field_enabled, field_number => '0012',
            show_second_harvest_date => $date_enabled, second_harvest_date => '2017-August-21',
        );
        my $details = render('/page/detail_page_2_col_section.mas', %args);
        my $dialog = render('/breeders_toolbox/trial/edit_trial_details_dialog.mas', %args);
        is(($details =~ /id="field_number"/ ? 1 : 0), $field_enabled, 'field number display follows its config switch');
        is(($dialog =~ /id="edit_trial_field_number"/ ? 1 : 0), $field_enabled, 'field number editor follows its config switch');
        is(($details =~ /id="second_harvest_date"/ ? 1 : 0), $date_enabled, 'second harvest display follows its config switch');
        is(($dialog =~ /id="edit_trial_second_harvest_date"/ ? 1 : 0), $date_enabled, 'second harvest editor follows its config switch');
        if ($field_enabled && $date_enabled) {
            like($details, qr/id="test_trial_barcode".*id="plot_width".*id="field_number".*0012.*id="second_harvest_date".*2017-August-21/s, 'values appear in the table below the barcode');
            like($dialog, qr/id="edit_trial_field_number"[^>]*value="0012"/, 'editor loads the saved field number');
            like($dialog, qr/id="edit_trial_second_harvest_date"[^>]*value="2017-August-21"/, 'editor loads the saved second harvest date');
        }
    }
}

my %enabled = (show_field_number => 1, show_second_harvest_date => 1);
my $default_details = render('/page/detail_page_2_col_section.mas');
unlike($default_details, qr/id="(?:field_number|second_harvest_date)"/, 'optional fields are hidden by default');
my $default_dialog = render('/breeders_toolbox/trial/edit_trial_details_dialog.mas');
unlike($default_dialog, qr/id="edit_trial_(?:field_number|second_harvest_date)"/, 'optional editors are hidden by default');
my $empty = render('/page/detail_page_2_col_section.mas', %enabled);
like($empty, qr/\[No Field Number\]/, 'empty field number has a placeholder');
like($empty, qr/\[No Second Harvest Date\]/, 'empty second harvest date has a placeholder');
my $zero = render('/page/detail_page_2_col_section.mas', %enabled, field_number => '0');
like($zero, qr/id="field_number">\s*0\s*</, 'zero field number is displayed');
my $escaped = render('/page/detail_page_2_col_section.mas', %enabled, field_number => '<script>');
like($escaped, qr/&lt;script&gt;/, 'field number is escaped in the table');
my $escaped_dialog = render('/breeders_toolbox/trial/edit_trial_details_dialog.mas', %enabled, field_number => '"<script>');
like($escaped_dialog, qr/value="&quot;&lt;script&gt;"/, 'field number is escaped in the editor');
ok($interp->load('/breeders_toolbox/trial.mas'), 'trial page compiles with the optional arguments');

done_testing();
