
# Label designer downloads: ranges, "Limit by Rep", ZPL fields, barcodes that
# cannot be made, the last page and the sheet checks (issue #6493), QR codes of
# trait values (issue #5763), and Cyrillic, Japanese and Chinese values.

use strict;
use warnings;
use utf8;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use CAM::PDF;
use File::Slurp;
use JSON;
use Encode;
use File::Temp qw(tempdir);
use CXGN::List;

my $f = SGN::Test::Fixture->new();
my $schema = $f->bcs_schema;
my $mech = Test::WWW::Mechanize->new;

my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();
ok($trial_id, 'found test_trial');

my $text_element = {
    x => 200, y => 50, height => 20, width => 300,
    value => 'L:{plot_name}:{rep_number}:{Number:1:1}',
    type => 'PDFText', font => 'Courier', size => '20',
};

sub pdf_design {
    my %extra = @_;
    return {
        page_format => 'US Letter PDF',
        page_width => 611, page_height => 790.7,
        left_margin => 13.68, top_margin => 36.7,
        horizontal_gap => 10, vertical_gap => 0,
        number_of_columns => 3, number_of_rows => 10,
        plot_filter => 'all',
        copies_per_plot => '1',
        sort_order_1 => 'plot_number',
        label_width => 189, label_height => 72,
        label_elements => [ $text_element ],
        %extra,
    };
}

sub zpl_design {
    my %extra = @_;
    return {
        page_format => 'Zebra printer file',
        page_width => '', page_height => '',
        copies_per_plot => '1',
        sort_order_1 => 'plot_number',
        label_width => 144, label_height => 90,
        label_elements => [ { %$text_element, type => 'ZebraText' } ],
        %extra,
    };
}

sub download {
    my ($type, $design, %source) = @_;
    $mech->post_ok('http://localhost:3010/tools/label_designer/download', [
        download_type => $type,
        data_type => $source{data_type} // 'Field Trials',
        source_id => $source{source_id} // $trial_id,
        source_name => 'test_trial',
        data_level => $source{data_level} // 'plots',
        design_json => encode_json($design),
    ]);
    return decode_json($mech->content);
}

# the labels in a PDF, as [ plot_name, rep, number ], and the page count
sub pdf_labels {
    my $response = shift;
    my $pdf = CAM::PDF->new($response->{filepath});
    my @labels;
    foreach my $page (1 .. $pdf->numPages()) {
        my $text = $pdf->getPageText($page) // '';
        push @labels, [ $1, $2, $3 ] while $text =~ /L:(\S+?):(\d+):(\d+)/g;
    }
    return (\@labels, $pdf->numPages());
}

sub zpl_labels {
    my $response = shift;
    my $zpl = read_file($response->{filepath});
    my @labels;
    push @labels, [ $1, $2, $3 ] while $zpl =~ /L:(\S+?):(\d+):(\d+)/g;
    return \@labels;
}

# reference: every plot, in the printed order
my $response = download('pdf', pdf_design());
my ($all) = pdf_labels($response);
is(scalar(@$all), 15, 'all 15 plots of test_trial are printed');
my @all_plots = map { $_->[0] } @$all;
is_deeply([ map { $_->[2] } @$all ], [ 1 .. 15 ], '{Number} counts 1 to 15');

# 1. Ranges
my $labels;
($labels) = pdf_labels(download('pdf', pdf_design(labels_to_download => 1)));
is_deeply([ map { $_->[0] } @$labels ], [ $all_plots[0] ], 'Total 1 prints one label');

($labels) = pdf_labels(download('pdf', pdf_design(start_number => 1, end_number => 1)));
is_deeply([ map { $_->[0] } @$labels ], [ $all_plots[0] ], 'Start 1 / End 1 prints one label');

($labels) = pdf_labels(download('pdf', pdf_design(start_number => 5, labels_to_download => 3)));
is_deeply([ map { $_->[0] } @$labels ], [ @all_plots[4 .. 6] ], 'Start 5 with Total 3 prints labels 5 to 7');
is_deeply([ map { $_->[2] } @$labels ], [ 5, 6, 7 ], '{Number} follows the label position');

my ($first_batch) = pdf_labels(download('pdf', pdf_design(start_number => 1, end_number => 10)));
my ($second_batch) = pdf_labels(download('pdf', pdf_design(start_number => 11, end_number => 20)));
is_deeply([ map { $_->[0] } @$first_batch, @$second_batch ], \@all_plots, 'batches 1-10 and 11-20 print every label once');

$response = download('pdf', pdf_design(start_number => 16));
like($response->{error}, qr/Start Number 16 is past the last label: there are 15 labels/, 'a Start past the end is refused');
$response = download('pdf', pdf_design(start_number => 5, end_number => 4));
like($response->{error}, qr/End Number \(4\) is smaller than Start Number \(5\)/, 'End before Start is refused');

# 2. Limit by Rep
my @rep2_plots = map { $_->[0] } grep { $_->[1] eq '2' } @$all;
ok(scalar(@rep2_plots) >= 3, 'test_trial has plots in rep 2');

($labels) = pdf_labels(download('pdf', pdf_design(plot_filter => '2')));
is_deeply([ map { $_->[0] } @$labels ], \@rep2_plots, 'PDF Limit by Rep 2 prints only rep 2');
is_deeply([ map { $_->[2] } @$labels ], [ 1 .. scalar(@rep2_plots) ], '{Number} does not skip with a rep filter');

($labels) = pdf_labels(download('pdf', pdf_design(plot_filter => '2', labels_to_download => 3)));
is_deeply([ map { $_->[0] } @$labels ], [ @rep2_plots[0 .. 2] ], 'Rep 2 with Total 3 prints the first 3 plots of rep 2');

$labels = zpl_labels(download('zpl', zpl_design(plot_filter => '2')));
is_deeply([ map { $_->[0] } @$labels ], \@rep2_plots, 'ZPL Limit by Rep 2 prints only rep 2');

$labels = zpl_labels(download('zpl', zpl_design(plot_filter => '2', start_number => 2, labels_to_download => 2)));
is_deeply([ map { $_->[0] } @$labels ], [ @rep2_plots[1 .. 2] ], 'ZPL range counts only the labels of the rep');

$response = download('pdf', pdf_design(plot_filter => '99'));
like($response->{error}, qr/no labels to print for rep 99/, 'a rep with no plots is refused');

# 3. ZPL fields
my $zpl_design = zpl_design(
    text_alignment => 'left',
    label_elements => [
        { x => 100, y => 40, height => 20, width => 50, value => '{plot_name}', type => 'ZebraText', font => 'Courier', size => '20' },
        { x => 200.4, y => 120.6, height => 38, width => 242, value => '{plot_name}', type => 'Code128', font => 'Courier', size => '1' },
    ],
);
my $zpl = read_file(download('zpl', $zpl_design)->{filepath});
like($zpl, qr/^\^LL255\^PW408$/m, '^LL and ^PW are whole dots');
like($zpl, qr/^\^FO100,30\^AA,20\^FD\Q$all_plots[0]\E\^FS$/m, 'left aligned text starts at its x');
like($zpl, qr/^\^F[O]79,102\^BCN,25,N,N,N\^FD\Q$all_plots[0]\E\^FS$/m, 'Code128 data has no leading spaces and its position is whole dots');
unlike($zpl, qr/\^(?:F[O]|LL|PW)[^\^]*\./, 'no decimals in field positions, ^LL or ^PW');

$zpl_design->{text_alignment} = 'middle';
$zpl = read_file(download('zpl', $zpl_design)->{filepath});
like($zpl, qr/^\^FO75,30\^AA,20\^FD/m, 'centred text is still placed by its centre');

# 4. Barcodes that cannot be made
my $barcode_design = pdf_design(label_elements => [
    $text_element,
    { x => 60, y => 60, height => 100, width => 100, value => '{seedlot_name}', type => 'QRCode', font => 'Courier', size => '5' },
    { x => 300, y => 150, height => 38, width => 242, value => 'Сорт {plot_number}', type => 'Code128', font => 'Courier', size => '1' },
    { x => 300, y => 100, height => 38, width => 242, value => '{plot_name}', type => 'Code128', font => 'Courier', size => '1' },
]);
$response = download('pdf', $barcode_design);
ok(!$response->{error}, 'a design with barcodes that cannot be made still gives a file') or diag explain $response;
($labels) = pdf_labels($response);
is(scalar(@$labels), 15, 'every label is printed');
my @warnings = @{$response->{warnings} || []};
is(scalar(@warnings), 2, 'two warnings: the empty QR code and the Cyrillic Code128');
like($warnings[0], qr/QRCode barcode "\{seedlot_name\}" was left blank on 15 label\(s\).*the value is empty/, 'empty QR value is reported');
like(decode('UTF-8', encode('UTF-8', $warnings[1])), qr/Code128 barcode "Сорт \{plot_number\}" was left blank on 15 label\(s\).*use a QR code/, 'non-ASCII Code128 value is reported');

$response = download('zpl', zpl_design(label_elements => [ { x => 60, y => 60, height => 100, width => 100, value => '{seedlot_name}', type => 'QRCode', font => 'Courier', size => '5' } ]));
like($response->{warnings}[0], qr/QRCode barcode "\{seedlot_name\}" was left blank on 15 label/, 'ZPL reports the empty QR value too');

$mech->get('http://localhost:3010/tools/label_designer/preview?content=&type=QRCode&size=5');
is($mech->status, 400, 'empty QR preview answers 400');
like($mech->content, qr/no value to encode/, 'with a reason');
$mech->get('http://localhost:3010/tools/label_designer/preview?content=%D0%A1%D0%BE%D1%80%D1%82&type=Code128&size=1');
is($mech->status, 400, 'non-ASCII Code128 preview answers 400');
like($mech->content, qr/plain ASCII/, 'with a reason');
$mech->get_ok('http://localhost:3010/tools/label_designer/preview?content=%D0%A1%D0%BE%D1%80%D1%82&type=QRCode&size=5', 'a Cyrillic QR preview works');

# 5. Labels that exactly fill the last sheet
my $pages;
($labels, $pages) = pdf_labels(download('pdf', pdf_design(number_of_rows => 5)));
is(scalar(@$labels), 15, '15 labels on a 3 x 5 sheet');
is($pages, 1, 'no blank page after a full sheet');
($labels, $pages) = pdf_labels(download('pdf', pdf_design(number_of_rows => 2)));
is($pages, 3, '15 labels on a 3 x 2 sheet use 3 pages');

# 6. Checks
my %bad_settings = (
    'copies 0' => [ { copies_per_plot => 0 }, qr/Copies per label must be a whole number of 1 or more/ ],
    'empty columns' => [ { number_of_columns => '' }, qr/Number of columns must be a whole number/ ],
    'empty rows' => [ { number_of_rows => '' }, qr/Number of rows must be a whole number/ ],
    'page 0 x 0' => [ { page_width => 0, page_height => 0 }, qr/page width and height must be larger than 0/ ],
    'start row past the sheet' => [ { start_row => 11 }, qr/Start Row must be between 1 and 10/ ],
    'total 0' => [ { labels_to_download => 0 }, qr/Total # to download must be a whole number of 1 or more/ ],
);
foreach my $case (sort keys %bad_settings) {
    my ($settings, $message) = @{$bad_settings{$case}};
    $response = download('pdf', pdf_design(%$settings));
    like($response->{error}, $message, "$case is refused with a message");
}

$response = download('pdf', pdf_design(), data_type => 'Lists', source_id => 999999, data_level => 'list');
like($response->{error}, qr/has no items to make labels from|not linked to a valid field design/, 'an empty or missing list is refused with a message');

# 7. Missing or unreadable ID batch
$response = download('pdf', pdf_design(), data_type => 'Lists', source_id => 999999, data_level => 'batch-1');
like($response->{error}, qr/not linked to a valid field design/, 'an ID batch of a missing list is refused with a message');

# The QR code printed on each PDF page, read back with zbarimg from a 300 dpi
# rendering, so use one label per page. zbarimg reads the raw bytes, which are
# decoded as UTF-8 here (in text mode it guesses, and reads Japanese as
# Shift-JIS). Undef when Ghostscript or zbarimg is not installed.
sub scan_qr_codes {
    my $pdf_file = shift;
    my $have_tools = system('which gs zbarimg > /dev/null 2>&1') == 0;
    return if !$have_tools;
    my $dir = tempdir(CLEANUP => 1);
    system('gs', '-q', '-dNOPAUSE', '-dBATCH', '-dSAFER', '-sDEVICE=pnggray', '-r300', "-sOutputFile=$dir/page-%03d.png", $pdf_file) == 0 or return;
    my @codes;
    foreach my $png (sort glob("$dir/page-*.png")) {
        my $bytes = `zbarimg -q --raw -Sbinary $png 2>/dev/null`;
        next if $bytes eq '';
        $bytes =~ s/\n$//;
        push @codes, decode('UTF-8', $bytes);
    }
    return \@codes;
}

# 8. QR codes of trait values (issue #5763): plots without a value leave the QR
# code blank and are listed; the others get their value
my $trait = 'dry matter content percentage|CO_334:0000092';
my $kasese_id = $schema->resultset('Project::Project')->find({ name => 'Kasese solgs trial' })->project_id();
$response = download('pdf', pdf_design(
    labels_to_download => 30,
    number_of_columns => 1, number_of_rows => 1, # one QR code per page for scan_qr_codes
    label_elements => [
        $text_element,
        { x => 300, y => 100, height => 100, width => 100, value => "{$trait}", type => 'QRCode', font => 'Courier', size => '5' },
    ],
), source_id => $kasese_id);
ok(!$response->{error}, 'a QR code of a trait downloads') or diag explain $response;
is($response->{labels}, 30, '30 labels');
my $blank_trait_labels = 0;
foreach my $warning (@{$response->{warnings} || []}) {
    like($warning, qr/^The QRCode barcode "\{\Q$trait\E\}" was left blank on (\d+) label.*the value is empty/, 'only plots without a value are reported');
    ($blank_trait_labels) = $warning =~ /on (\d+) label/;
}
my $codes = scan_qr_codes($response->{filepath});
SKIP: {
    skip 'Ghostscript or zbarimg is not installed', 2 if !$codes;
    is(scalar(@$codes), 30 - $blank_trait_labels, 'every plot with a value has a QR code');
    is(scalar(grep { /^-?\d+(?:\.\d+)?$/ } @$codes), scalar(@$codes), 'the QR codes hold the trait values');
}

# 9. Cyrillic, Japanese and Chinese names, read from the database
$mech->post_ok('http://localhost:3010/brapi/v1/token', [ username => 'janedoe', password => 'secretpw', grant_type => 'password' ], 'login as janedoe, the list owner');
my @names = ('Сорт-1', '品種-2', '品种-3', 'plot-4');
my $list_id = CXGN::List::create_list($f->dbh(), 'label_designer_unicode_names', 'Cyrillic, Japanese and Chinese names', 41);
my $list = CXGN::List->new({ dbh => $f->dbh(), list_id => $list_id });
$list->add_bulk([ @names ]);
my %list_source = (data_type => 'Lists', source_id => $list_id, data_level => 'list');

my $unicode_text = { x => 200, y => 50, height => 20, width => 300, value => '{list_item_name}', type => 'PDFText', font => 'Courier', size => '20' };
my $unicode_qr = { x => 60, y => 60, height => 100, width => 100, value => '{list_item_name}', type => 'QRCode', font => 'Courier', size => '5' };
$response = download('pdf', pdf_design(sort_order_1 => 'list_item_name', number_of_columns => 1, number_of_rows => 1, label_elements => [ $unicode_text, $unicode_qr ]), %list_source);
ok(!$response->{error}, 'a PDF of Cyrillic, Japanese and Chinese names downloads') or diag explain $response;
is($response->{labels}, 4, 'four labels');
ok(!$response->{warnings}, 'nothing is left out') or diag explain $response->{warnings};
my $pdf_bytes = read_file($response->{filepath}, binmode => ':raw');
like($pdf_bytes, qr{/BaseFont\s*/(?:\w+\+)?DejaVuSansMono}, 'Cyrillic is printed with DejaVu Sans Mono, the Unicode match of Courier');
like($pdf_bytes, qr{/BaseFont\s*/(?:\w+\+)?DroidSansFallback}, 'Japanese and Chinese are printed with Droid Sans Fallback');
like($pdf_bytes, qr{/BaseFont\s*/Courier\b}, 'Latin text keeps Courier');
# A PDF::API2 subset of Droid Sans Fallback (about 0.3 MB) loses most Chinese and
# Japanese glyphs, which then print as empty boxes; the whole font is about 3.9 MB.
ok((grep { $_ > 3_000_000 } $pdf_bytes =~ m{/Length1 (\d+)}g), 'Droid Sans Fallback is embedded whole, not as a subset');
$codes = scan_qr_codes($response->{filepath});
SKIP: {
    skip 'Ghostscript or zbarimg is not installed', 1 if !$codes;
    is_deeply([ sort @$codes ], [ sort @names ], 'the QR codes hold the Cyrillic, Japanese and Chinese names');
}

$response = download('pdf', pdf_design(sort_order_1 => 'list_item_name', label_elements => [ { %$unicode_qr, type => 'Code128', height => 38, width => 242, size => '1' } ]), %list_source);
like($response->{warnings}[0], qr/Code128 barcode "\{list_item_name\}" was left blank on 3 label\(s\).*use a QR code/, 'Code128 leaves out only the three non-Latin names');

$response = download('pdf', pdf_design(label_elements => [ { %$unicode_text, value => "Ref \x{13000} {list_item_name}" } ]), %list_source);
like($response->{warnings}[0], qr/The text "Ref \x{13000} \{list_item_name\}" was printed without some characters on 4 label\(s\).*no installed font has \x{13000}/, 'a character no font has is reported');

$response = download('zpl', zpl_design(sort_order_1 => 'list_item_name', label_elements => [
    { %$unicode_text, type => 'ZebraText' },
    { %$unicode_qr },
]), %list_source);
my $zpl_text = read_file($response->{filepath}, binmode => ':encoding(UTF-8)');
my @zpl_labels = $zpl_text =~ /(\^XA.*?\^XZ)/sg;
is(scalar(@zpl_labels), 4, 'four ZPL labels');
foreach my $name (@names) {
    my ($zpl_label) = grep { /\^FDMA,\Q$name\E\^FS/ } @zpl_labels;
    ok($zpl_label, "the ZPL QR code holds $name");
    if ($name =~ /[^\x00-\x7F]/) {
        like($zpl_label // '', qr/^\^XA\n\^CI28\n/, "the $name label tells the printer its data is UTF-8");
    } else {
        unlike($zpl_label // '', qr/\^CI28/, "the $name label is unchanged");
    }
}
ok(!$response->{warnings}, 'the ZPL of Cyrillic, Japanese and Chinese names has no warnings') or diag explain $response->{warnings};

# Text outside Latin is drawn by the server and sent as a ^GFA image, because
# the printer's font A only has Latin characters. Latin text keeps font A.
my %zebra_text_images;
foreach my $name (@names) {
    my ($zpl_label) = grep { /\^FDMA,\Q$name\E\^FS/ } @zpl_labels;
    $zpl_label //= '';
    if ($name =~ /[^\x00-\x7F]/) {
        unlike($zpl_label, qr/\^AA,20\^FD\Q$name\E/, "$name is not sent to printer font A");
        my ($bytes, $total, $bytes_per_row, $hex) = $zpl_label =~ /\^GFA,(\d+),(\d+),(\d+),([0-9A-F]+)\^FS/;
        ok($hex, "$name is sent as an image");
        is(length($hex // ''), 2 * ($bytes // 0), "the $name image has as many bytes as it declares");
        is(($bytes // 0) % ($bytes_per_row || 1), 0, "the $name image has whole rows");
        my $black = () = unpack('B*', pack('H*', $hex // '')) =~ /1/g;
        ok($black > 20, "the $name image is not blank");
        $zebra_text_images{$name} = $hex // '';
    } else {
        like($zpl_label, qr/\^AA,20\^FD\Q$name\E\^FS/, "$name still uses printer font A");
        unlike($zpl_label, qr/\^GFA/, "$name has no image");
    }
}
isnt($zebra_text_images{'品種-2'}, $zebra_text_images{'品种-3'}, 'the Japanese and the Chinese names give different images');

$response = download('zpl', zpl_design(label_elements => [ { %$unicode_text, type => 'ZebraText', value => "Ref \x{13000} {list_item_name}" } ]), %list_source);
like($response->{warnings}[0], qr/The Zebra text "Ref \x{13000} \{list_item_name\}" was printed without some characters on 4 label\(s\).*no installed font has \x{13000}/, 'a Zebra character no font has is reported');

CXGN::List::delete_list($f->dbh(), $list_id);

done_testing();
