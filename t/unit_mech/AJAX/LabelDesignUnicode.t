#!/usr/bin/env perl
# The label designer (/tools/label_designer) keeps non-ASCII text — Ukrainian, accented
# Latin — in every path: the field preview (retrieve_longest_fields), a design that holds its own
# non-ASCII text, PDF labels (text a PDF core font cannot draw uses the matching Liberation TrueType
# font; Latin-1 text keeps the core font as before) and ZPL labels (^CI28 and UTF-8 bytes for a
# label with non-ASCII text; ASCII labels unchanged).
# The trial's management factor carries the non-ASCII text into the {brief_management_regime} and
# {full_management_regime} fields. Runs against the disposable fixture database and server.
use strict;
use warnings;
use utf8;
use Test::More;
use Catalyst::Test 'SGN';
use Encode ();
use JSON ();
use Test::WWW::Mechanize;
use URI;
use SGN::Model::Cvterm;

binmode(Test::More->builder->$_, ':encoding(UTF-8)') for qw(output failure_output todo_output);

my (undef, $context) = ctx_request('/');
ok($context, 'fixture provides a Catalyst context') or BAIL_OUT('No fixture context');
my $schema = $context->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
my $dbh = $schema->storage->dbh;
my ($database) = $dbh->selectrow_array('SELECT current_database()');
BAIL_OUT('Refusing any non-fixture database')
    unless defined($database) && $database =~ /\Atest_db_[0-9_]+\z/;
my $server = $ENV{SGN_TEST_SERVER} || 'http://localhost:3010';
BAIL_OUT('Refusing HTTP requests outside the disposable fixture')
    unless URI->new($server)->host =~ /\A(?:localhost|127\.0\.0\.1|test_breedbase)\z/;

my $mech = Test::WWW::Mechanize->new(autocheck => 0);
$mech->post("$server/ajax/user/login", { username => 'janedoe', password => 'secretpw', goto_url => '/' });
ok($mech->status == 200 && !(eval { JSON::decode_json($mech->content)->{error} }), 'janedoe signs in')
    or BAIL_OUT('Fixture login failed: ' . $mech->content);

my $trial_id = $schema->resultset('Project::Project')->find({ name => 'test_trial' })->project_id();
my $regime_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'management_regime', 'project_property')->cvterm_id();
my ($saved_regime) = $dbh->selectrow_array(
    'SELECT value FROM projectprop WHERE project_id = ? AND type_id = ?', undef, $trial_id, $regime_type_id);
END {
    eval {
        $dbh->do('DELETE FROM projectprop WHERE project_id = ? AND type_id = ?', undef, $trial_id, $regime_type_id);
        $dbh->do('INSERT INTO projectprop (project_id, type_id, value) VALUES (?, ?, ?)',
            undef, $trial_id, $regime_type_id, $saved_regime) if defined $saved_regime;
        1;
    } or diag "fixture restore failed: $@";
}

# One management factor with Ukrainian text, stored the way the trial page stores it.
my $factor = 'T3 BBCH 60–65: Ревікер 0,7 л/га';
$dbh->do('DELETE FROM projectprop WHERE project_id = ? AND type_id = ?', undef, $trial_id, $regime_type_id);
{
    my $uri = URI->new("$server/ajax/breeders/trial/$trial_id/edit_management_factor_details");
    my %query = (type => 'Fungicide', description => $factor, schedule => 'один раз', start_date => '2026-06-15',
                 end_date => '2026-06-15', completions => '[]', action => 'add');
    $uri->query_form(map { $_ => Encode::encode('UTF-8', $query{$_}) } sort keys %query);
    $mech->get($uri);
    ok($mech->status == 200 && (eval { JSON::decode_json($mech->content)->{success} }), 'management factor stored')
        or diag $mech->content;
}

# Field preview of the label designer: what the page shows next to each field name.
$mech->post("$server/tools/label_designer/retrieve_longest_fields",
    { data_type => 'Field Trials', source_id => $trial_id, data_level => 'plots' });
is($mech->status, 200, 'retrieve_longest_fields: HTTP 200') or diag $mech->content;
my $fields = (eval { JSON::decode_json($mech->content) } || {})->{fields} || {};
like($fields->{brief_management_regime} // '', qr/\Q$factor\E/, 'preview: brief management regime as typed')
    or diag $fields->{brief_management_regime};
my $full = eval { JSON->new->decode($fields->{full_management_regime} // '') } || [];
is(ref $full eq 'ARRAY' ? $full->[0]{description} : undef, $factor, 'preview: full management regime as typed')
    or diag $fields->{full_management_regime};

my $own_text = 'Сорт: {accession_name} – Müller';
my $accession = $schema->resultset('Stock::Stock')->search(
    { 'me.type_id' => SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id() })->first;

sub download {
    my ($type, $elements, $copies) = @_;
    my $design = {
        page_width => 611, page_height => 791, left_margin => 13.68, top_margin => 36.7,
        horizontal_gap => 10, vertical_gap => 0, number_of_columns => 3, number_of_rows => 10,
        label_width => 189, label_height => 72, copies_per_plot => $copies || 1, plot_filter => 'all',
        sort_order_1 => 'plot_name', text_alignment => 'middle', labels_to_download => 2,
        label_elements => $elements,
    };
    # The page posts design_json as a form field (UTF-8).
    $mech->post("$server/tools/label_designer/download", {
        download_type => $type, data_type => 'Field Trials', data_level => 'plots', source_id => $trial_id,
        source_name => 'test_trial', design_json => Encode::encode('UTF-8', JSON->new->encode($design)) });
    my $answer = eval { JSON::decode_json($mech->content) } || {};
    ok($mech->status == 200 && $answer->{filepath} && -s $answer->{filepath}, "$type download answers with a file")
        or diag $mech->status . ' ' . substr($mech->content, 0, 600);
    return unless $answer->{filepath} && -s $answer->{filepath};
    open my $fh, '<:raw', $answer->{filepath} or return;
    local $/;
    my $bytes = <$fh>;
    close $fh;
    return { bytes => $bytes, path => $answer->{filepath} };
}

# PDF: own text and fields with non-ASCII text; the plot name stays ASCII.
my $pdf = download('pdf', [
    { type => 'PDFText', x => 280, y => 40, width => 200, height => 20, size => 20, font => 'Helvetica', value => '{plot_name}' },
    { type => 'PDFText', x => 280, y => 90, width => 400, height => 20, size => 20, font => 'Helvetica-Bold', value => $own_text },
    { type => 'PDFText', x => 280, y => 140, width => 400, height => 20, size => 16, font => 'Times', value => '{full_management_regime}' },
]);
SKIP: {
    skip 'no PDF file', 4 unless $pdf;
    my $text = Encode::decode('UTF-8', scalar `mutool draw -q -F txt -o - '$pdf->{path}' 2>/dev/null`);
    like($text, qr/Сорт: .+ – Müller/, 'PDF: own Ukrainian and accented text is drawn') or diag $text;
    like($text, qr/\Q$factor\E/, 'PDF: management factor text is drawn') or diag $text;
    my $fonts = `mutool info -F '$pdf->{path}' 2>/dev/null`;
    like($fonts, qr/'LiberationSans-?Bold'/, 'PDF: non-Latin-1 text uses the Liberation font of its family') or diag $fonts;
    like($fonts, qr/\bHelvetica\b(?!-)/, 'PDF: ASCII text keeps the core font') or diag $fonts;
}

# ZPL: the same; the printer gets UTF-8 with ^CI28.
my $zpl = download('zpl', [
    { type => 'ZebraText', x => 100, y => 40, width => 200, height => 20, size => 20, value => '{plot_name}' },
    { type => 'ZebraText', x => 100, y => 90, width => 400, height => 20, size => 20, value => $own_text },
    { type => 'ZebraText', x => 100, y => 140, width => 400, height => 20, size => 16, value => '{full_management_regime}' },
]);
SKIP: {
    skip 'no ZPL file', 4 unless $zpl;
    my $bytes = $zpl->{bytes};
    my $text = eval { Encode::decode('UTF-8', $bytes, Encode::FB_CROAK) };
    ok(defined $text, 'ZPL: the file is valid UTF-8') or diag $@;
    $text //= '';
    my @labels = $text =~ /\^XA/g;
    my @declared = $text =~ /\^XA\s*\^CI28/g;
    ok(@labels == 2 && @declared == @labels, 'ZPL: both labels declare UTF-8 (^CI28)') or diag $text;
    like($text, qr/\^FDСорт: .+ – Müller\^FS/, 'ZPL: own Ukrainian and accented text as typed') or diag $text;
    like($text, qr/\Q$factor\E/, 'ZPL: management factor text as typed') or diag $text;
}

# An ASCII design whose field brings Ukrainian text from the trial (the case of a trial's own data).
my $field_pdf = download('pdf', [ { type => 'PDFText', x => 280, y => 40, width => 400, height => 20, size => 14,
                                    font => 'Courier', value => 'Pass: {brief_management_regime}' } ]);
SKIP: {
    skip 'no PDF file', 1 unless $field_pdf;
    my $text = Encode::decode('UTF-8', scalar `mutool draw -q -F txt -o - '$field_pdf->{path}' 2>/dev/null`);
    like($text, qr/Ревікер 0,7 л\/га/, 'PDF, ASCII design: Ukrainian field text is drawn') or diag $text;
}
my $field_zpl = download('zpl', [ { type => 'ZebraText', x => 100, y => 40, width => 400, height => 20, size => 20,
                                    value => 'Pass: {full_management_regime}' } ], 2);
SKIP: {
    skip 'no ZPL file', 1 unless $field_zpl;
    my $text = eval { Encode::decode('UTF-8', $field_zpl->{bytes}, Encode::FB_CROAK) } // '';
    my @labels = $text =~ /\^XA\n/g;
    my @declared = $text =~ /\^XA\n\^CI28\n/g;
    ok(@labels == 4 && @declared == 4 && $text =~ /\Q$factor\E/,
       'ZPL, ASCII design, 2 copies: 4 labels, each declares UTF-8, Ukrainian field text as typed')
        or diag $field_zpl->{bytes};
}

# ASCII-only labels: same fonts and bytes as before.
my $ascii = download('zpl', [ { type => 'ZebraText', x => 100, y => 40, width => 200, height => 20, size => 20,
                                value => 'Plot {plot_name}' } ]);
ok($ascii && $ascii->{bytes} =~ /\A\^XA\n\^LL/ && $ascii->{bytes} =~ /\^FDPlot [\x20-\x7e]+\^FS/
   && $ascii->{bytes} !~ /\^CI28/ && $ascii->{bytes} !~ /[^\x00-\x7f]/,
   'ZPL: ASCII labels are unchanged (no ^CI28, ASCII bytes only)') or diag $ascii ? $ascii->{bytes} : 'no file';

done_testing();
