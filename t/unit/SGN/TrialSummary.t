package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin;
use JSON::PP;
use Encode qw(decode);
use HTML::Entities qw(encode_entities);
use HTML::Mason::Interp;
use Time::Piece;
use SGN::I18N;

# Real native summary and barcode templates. Synthetic display data and language
# catalogs; no database, layout generation, auth mutation or barcode HTTP request.
my %captions = (
    name => 'Trial Name', program => 'Breeding Program ', location => 'Trial Location', year => 'Year',
    stock_type => 'Stock Type Being Evaluated in This Trial', stock_count => 'Number of Stocks in This Trial',
    type => 'Trial Type', planting_date => 'Planting Date', transplanting_date => 'Transplanting Date',
    harvest_date => 'Harvest Date', description => 'Description', folder => 'Folder', owner => 'Created by',
    latest_activity => 'Latest Trial Activity', plot_name_template => 'Plot Name Template',
    plot_width => 'Plot Width (m)', plot_length => 'Plot Length (m)', field_size => 'Field Size (ha)',
    planned_genotyping => 'Trial Will Be Genotyped', planned_crossing => 'Trial Will Be In Crosses',
);
my %empty = (name => '[No Trial Name]', program => '[No Breeding Program]', location => '[No Location]',
    year => '[No Year]', stocks => '[No Stocks in Trial]', type => '[Type not set]',
    planting_date => '[No Planting Date]', harvest_date => '[No Harvest Date]', description => '[No Description]',
    owner => '[N/A]', activity => '[No Record]', plot_width => '[No Plot Width]', plot_length => '[No Plot Length]', field_size => '[No Field Size]');
my %sources = ((map {("trial.summary.label.$_" => $captions{$_})} keys %captions),
    (map {("trial.summary.empty.$_" => $empty{$_})} keys %empty),
    'trial.summary.folder.new' => 'New Folder', 'trial.summary.folder.change' => 'Change Folder',
    'trial.summary.plan.yes' => 'yes', 'trial.summary.plan.no' => 'no');
my %prefix = (en => '', uk => 'Українська: ', es => 'Español: ', ar => 'العربية: ');
my $root = tempdir(CLEANUP => 1);
my $json = JSON::PP->new->canonical;
my $adverse = ' <img src=x onerror="unit()"> & "literal"';
for my $locale (qw(uk es ar)) {
    make_path("$root/$locale");
    my %messages = map {("$_\x04$sources{$_}" => {plural => undef, forms => [$prefix{$locale}.$sources{$_}.$adverse]})} keys %sources;
    open my $out, '>:raw', "$root/$locale/sgn.json" or die $!;
    print {$out} $json->utf8->encode({schema => 1, api => 1, locale => $locale, direction => $locale eq 'ar' ? 'rtl' : 'ltr', sourceRevision => '0' x 64,
        nplurals => 1, pluralForms => 'nplurals=1; plural=0;', pluralAst => {type => 'NUM', val => 0}, messages => \%messages});
    close $out;
}
{
    package Local::TrialSummary::Context;
    sub new { bless {translator => $_[1], conf => $_[2] || {}}, $_[0] }
    sub i18n { $_[0]->{translator} }
    sub get_conf { $_[0]->{conf}{$_[1]} }
}
my $output;
my $interp = HTML::Mason::Interp->new(comp_root => "$FindBin::Bin/../../../mason", data_dir => tempdir(CLEANUP => 1),
    allow_globals => ['$c'], preamble => 'use utf8;', out_method => \$output, autohandler_name => '__unit_no_autohandler__');
sub render {
    my ($locale, $args, $conf) = @_;
    $output = '';
    $interp->set_global('$c', Local::TrialSummary::Context->new(SGN::I18N->new(locale => $locale, catalog_root => $root), $conf));
    $interp->exec('/breeders_toolbox/trial/trial_details.mas', %$args);
    return $output;
}
my $plain = 'Сорт_已更新_العربية <img src=x onerror="unit()"> & literal';
my $owner = '<a href="/solpeople/personal-info.pl?sp_person_id=41">Owner Опис_العربية</a> 2026-01-01<br />';
my $template = {'Шаблон_العربية <tag>' => {name_attributes => [{text => $plain}, 'plot_number']}};
my %args = (trial_id => 137, trial_name => $plain, breeding_program_name => $plain, breeding_program_id => 134,
    location_name => $plain, country_name => $plain, year => 2026, trial_type => 'misc_trial', planting_date => '2020-January-01',
    transplanting_date => '2020-January-02', harvest_date => '2020-February-01', trial_description => "$plain\n17.25 kg",
    folder_name => $plain, folder_id => 77, identifier_prefix => 'test', plot_width => 0.5, plot_length => 2.25, field_size => 1.75,
    field_trial_is_planned_to_be_genotyped => 'yes', field_trial_is_planned_to_cross => 'no', trial_stock_type => 'accession', trial_stock_count => 4,
    trial_owner => $owner, latest_trial_activity => 'Started Phenotyping : 2026-March-03', plot_name_template => undef);
my @ids = qw(trial_name breeding_program trial_location trial_year stock_type_in_trial stock_number_in_trial trial_type planting_date
    transplanting_date harvest_date trial_description trial_folder_div new_folder_dialog_link open_folder_dialog_link trial_owner
    latest_trial_activity plot_name_template plot_width plot_length field_size planned_to_be_genotyped planned_to_cross);
for my $locale (qw(en uk es ar)) {
    subtest "$locale plain summary data, trusted owner HTML and canonical links" => sub {
        for my $storage ('characters', 'legacy-octets') {
            my %current = %args;
            my $source_json = JSON::PP->new->canonical->encode($template);
            $current{plot_name_template} = $storage eq 'characters' ? $source_json : decode('iso-8859-1', JSON::PP->new->canonical->utf8->encode($template));
            my $snapshot = JSON::PP->new->canonical->encode(\%current);
            my $html = render($locale, \%current, {display_dap_dah => 1, limit_dap => 30, limit_dah => 30});
            is(JSON::PP->new->canonical->encode(\%current), $snapshot, 'Renderer never mutates caller metadata');
            like($html, qr/\Q@{[encode_entities($plain)]}\E/, 'Unicode and literal HTML-like field text escaped exactly once');
            unlike($html, qr/<img\s+src=x/, 'No biological value or translation becomes injected markup');
            like($html, qr/\Q$owner\E/, 'Trusted owner anchor, identity and creation date preserved');
            like($html, qr{src="/barcode/trial/137/trial_qrcode"}, 'Original QR route and format unchanged');
            like($html, qr{href="/breeders/program/134"}, 'Program identifier and destination unchanged');
            like($html, qr{href="/folder/77"}, 'Folder identifier and destination unchanged');
            like($html, qr{href="/breeders/trial/137\?currentDate=2020-January-01"}, 'Date drill-down retains canonical date');
            like($html, qr/Started Phenotyping : 2026-March-03/, 'Latest activity key and date remain original data');
            like($html, qr/\Q@{[encode_entities('Шаблон_العربية <tag>')]}\E/, 'Both stored-JSON forms decode and escape Unicode template name');
            like($html, qr/\Q@{[encode_entities($plain.'_{plot_number}')]}\E/, 'Template attributes and machine field token remain intact');
            like($html, qr{DAP: &gt;30|DAP: >30}, 'Original numerical DAP limiting preserved');
            like($html, qr{DAH: &gt;30|DAH: >30}, 'Original numerical DAH limiting preserved');
            for my $id (@ids) { like($html, qr/id=["']\Q$id\E["']/, 'Original behavior hook retained: '.$id) }
            for my $key (keys %captions) {
                my $text = $prefix{$locale}.$captions{$key}.($locale eq 'en' ? '' : $adverse);
                like($html, qr/\Q@{[encode_entities($text)]}\E/, 'Complete owned caption localized and escaped: '.$key);
            }
        }
        my %blank = map { $_ => '' } keys %args;
        $blank{trial_id}=137;
        my $html = render($locale, \%blank);
        for my $key (keys %empty) {
            my $text = $prefix{$locale}.$empty{$key}.($locale eq 'en' ? '' : $adverse);
            like($html, qr/\Q@{[encode_entities($text)]}\E/, 'Original empty condition gets escaped whole notice: '.$key);
        }
        unlike($html, qr/id="transplanting_date"|id="plot_name_template"/, 'Original conditional rows stay absent');
        my %unknown = %args;
        $unknown{field_trial_is_planned_to_be_genotyped} = $plain;
        $unknown{field_trial_is_planned_to_cross} = $plain;
        $html = render($locale, \%unknown);
        like($html, qr/\Q@{[encode_entities($plain)]}\E/, 'Unknown configured planning value remains escaped data');
    };
}
subtest 'missing language packs preserve English captions and data' => sub {
    is(render('zz', \%args), render('en', \%args), 'Unavailable language falls back to full original English presentation');
};
done_testing;
