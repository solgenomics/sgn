package main;

=head1 NAME

t/unit/SGN/FolderPage.t - generic and typed folder dialogs render through the real views

=head1 DESCRIPTION

Render the real folder page and its real management dialogs with a request-local
translator. Generic folders have no project type; their legacy blank caption
must not prevent the page controls from rendering. Controlled catalogs exercise
English and three enabled locales without a database or browser server. Only
asset imports and unrelated download dialogs are stubbed.

=cut

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use File::Spec;
use FindBin;
use JSON::PP;
use HTML::Entities ();
use HTML::Mason::Interp;
use SGN::I18N;

{
    package Local::FolderPage::Context;
    sub i18n { $_[0]->{i18n} }
    package Local::FolderPage::Row;
    sub name { 'Native_Program' }
    sub project_id { 42 }
}

my $root = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..', '..', '..'));
my $tmp = tempdir(CLEANUP => 1);
for my $relative (qw(util/import_javascript.mas
    breeders_toolbox/trial/download_phenotypes_dialog.mas
    breeders_toolbox/genotyping_trials/download_genotyping_trial_layouts_dialogs.mas)) {
    my $path = "$tmp/stubs/$relative";
    (my $directory = $path) =~ s{/[^/]+$}{};
    make_path($directory);
    open my $out, '>', $path or die $!;
    close $out;
}
for my $locale (qw(uk es ar)) {
    make_path("$tmp/catalog/$locale");
    open my $out, '>:raw', "$tmp/catalog/$locale/sgn.json" or die $!;
    print {$out} JSON::PP->new->utf8->encode({
        schema => 1, api => 1, locale => $locale, direction => $locale eq 'ar' ? 'rtl' : 'ltr',
        nplurals => 1, pluralForms => 'nplurals=1; plural=0;',
        pluralAst => {type => 'NUM', val => 0},
        messages => {"folder.move.move_title\x04Move a %{type} folder" => {
            plural => undef, forms => ["$locale: Move a %{type} folder"],
        }},
    });
    close $out;
}
my $row = bless {}, 'Local::FolderPage::Row';
my %folder = (
    folder_id => 91, folder_name => 'Native_Folder', folder_description => 'Native description',
    trials => [], crossing_trials => [], genotyping_trials => [], genotyping_projects => [],
    analyses_trials => [], tracking_activities => [], child_folders => [],
    project_parent => $row, breeding_program => $row, folder_for_trials => 1,
    folder_for_crosses => 0, folder_for_genotyping_trials => 0, folder_for_genotyping_projects => 0,
    folder_for_tracking_activities => 0, folder_for_transformations => 0, has_child_folders => 0,
);
for my $locale (qw(en uk es ar)) {
    my $translator = SGN::I18N->new(locale => $locale, catalog_root => "$tmp/catalog");
    for my $mode (qw(generic typed)) {
        subtest "$locale $mode folder" => sub {
            my $html = '';
            my $interp = HTML::Mason::Interp->new(
                comp_root => [[stubs => "$tmp/stubs"], [source => "$root/mason"]],
                data_dir => "$tmp/cache", autohandler_name => '__unit_no_autohandler__',
                allow_globals => ['$c'], preamble => 'use utf8;', out_method => \$html,
            );
            $interp->set_global('$c', bless {i18n => $translator}, 'Local::FolderPage::Context');
            my $ok = eval {
                if ($mode eq 'generic') {
                    $interp->exec('/breeders_toolbox/folder/folder.mas', %folder);
                } else {
                    $interp->exec('/breeders_toolbox/folder/folder_move.mas',
                        project_type => 'field_trial', breeding_program_id => 42);
                }
                1;
            };
            ok($ok, 'actual views render without a missing presentation value') or diag($@);
            is($translator->locale, $locale, 'the requested translator is active');
            like($html, qr/id="move_folder_submit"/, 'move control remains available');
            like($html, qr/id="delete_folder_button"/, 'generic page retains its delete control')
                if $mode eq 'generic';
            my $expected = ($locale eq 'en' ? '' : "$locale: ") .
                ($mode eq 'generic' ? 'Move a  folder' : 'Move a trial folder');
            like($html, qr/\Q$expected\E/, 'legacy generic and typed captions retain their values');
            done_testing();
        };
    }
}
done_testing();
