package main;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use JSON::PP;
use SGN::I18N;
use CXGN::File::Parse;
use CXGN::File::Parse::Plugin::Plain;
use CXGN::File::Parse::Plugin::Spreadsheet;
use CXGN::Stock::ParseUpload;
use DBIx::Class::Schema;

# Real parsers and small UTF-8 files. The accession wrapper below receives a
# fail-closed schema sentinel solely to prove validation returns before any DB
# access. No source replacement, network, real database or mail dependencies.
{
    package Local::FileParseI18N::Schema;
    our @ISA = ('DBIx::Class::Schema');
    sub resultset { die 'Database access forbidden in parser presentation test' }
    package Local::FileParseI18N::Invalid;
    sub new { bless {}, shift }
}
my %source = (
    'file.parse.missing' => 'The file %{file} does not exist',
    'file.parse.required_column' => 'Required column %{column} is missing',
    'file.parse.required_value' => 'Required column %{column} does not have a value in row %{row}',
    'file.parse.duplicate_value' => 'Column %{column} requires unique values, but %{value} appears more than once in rows %{rows}',
    'file.parse.no_plugin' => 'No appropriate file parsing plugin for file: %{file}, type: %{type}',
    'file.parse.plain_type' => 'Invalid type %{type} for plain parse plugin',
    'file.parse.spreadsheet_type' => 'Invalid type %{type} for spreadsheet parse plugin',
    'file.parse.duplicate_header' => 'The column header %{header} was duplicated in column %{column} of your file and should only be included once.',
    'accessions.parse.unknown_columns' => 'The following columns are not recognized: %{columns}. Please check the spreadsheet format for the allowed columns.',
);
# Synthetic language markers test message routing/glyphs; they do not establish
# editorial quality of the separately maintained human translation catalogs.
my %prefix = (default => '', en => '', uk => 'Українська: ', es => 'Español: ', ar => 'العربية: ');
my $dir = tempdir(CLEANUP => 1);
my $catalog_root = "$dir/catalogs";
my $json = JSON::PP->new->utf8->canonical;
for my $locale (qw(uk es ar)) {
    make_path("$catalog_root/$locale");
    my %messages = map {("$_\x04$source{$_}" => {plural => undef, forms => [$prefix{$locale} . $source{$_}]})} keys %source;
    open my $f, '>:raw', "$catalog_root/$locale/sgn.json" or die $!;
    print {$f} $json->encode({schema => 1, api => 1, locale => $locale, direction => $locale eq 'ar' ? 'rtl' : 'ltr',
        sourceRevision => '0' x 64, nplurals => 1, pluralForms => 'nplurals=1; plural=0;', pluralAst => {type => 'NUM', val => 0}, messages => \%messages});
    close $f;
}
sub message {
    my ($locale, $key, $vars) = @_;
    my $text = $prefix{$locale} . $source{$key};
    $text =~ s/%\{([A-Za-z0-9_]+)\}/exists($vars->{$1}) ? $vars->{$1} : die("Missing expected variable $1")/ge;
    return $text;
}
sub write_csv {
    my ($name, $rows) = @_;
    my $path = "$dir/$name";
    open my $f, '>:encoding(UTF-8)', $path or die $!;
    for my $row (@$rows) {
        my @out = map {my $v = $_; $v =~ s/"/""/g; '"' . $v . '"'} @$row;
        print {$f} join(',', @out) . "\n";
    }
    close $f;
    return $path;
}
sub parser {
    my ($path, $translator, %options) = @_;
    return CXGN::File::Parse->new(file => $path, required_columns => ['accession_name', 'species_name'],
        optional_columns => ['description'], column_arrays => {}, unique_only_columns => ['accession_name'],
        defined($translator) ? (i18n => $translator) : (), %options);
}
sub normalized {
    my ($parsed) = @_;
    my $copy = $json->decode($json->encode($parsed));
    # The values accessor is a set encoded as arrays from Perl hash keys. Row
    # order and column order are preserved exactly; only these sets are sorted.
    for my $key (keys %{$copy->{values} || {}}) { $copy->{values}{$key} = [sort @{$copy->{values}{$key}}] }
    return $copy;
}
my $stock = 'Дослід_已更新_العربية <b> & "quoted" %{unrelated}';
my $description = 'Опис_已更新 العربية 17.25 kg & literal <tag>';
my $valid = write_csv('valid.csv', [[qw(accession_name species_name description)], [$stock, 'Manihot esculenta', $description]]);
my $missing = write_csv('missing.csv', [[qw(accession_name description)], [$stock, $description]]);
my $blank = write_csv('blank.csv', [[qw(accession_name species_name description)], [$stock, '', $description]]);
my $duplicate = write_csv('duplicate.csv', [[qw(accession_name species_name accession_name)], [$stock, 'Manihot esculenta', $stock]]);
my $repeat = write_csv('repeated.csv', [[qw(accession_name species_name)], [$stock, 'Manihot esculenta'], [$stock, 'Manihot esculenta']]);
my $unknown = write_csv('unknown.csv', [[qw(accession_name species_name), 'CO_334:Опис<field>'], [$stock, 'Manihot esculenta', $description]]);
my $unsupported = write_csv('unsupported.no_parser', [[qw(accession_name species_name)], [$stock, 'Manihot esculenta']]);
my $baseline = normalized(parser($valid, undef)->parse());
is_deeply($baseline->{columns}, [qw(accession_name species_name description)], 'Canonical header tokens and column order retained');
is_deeply($baseline->{data}, [{_row => 2, accession_name => $stock, species_name => 'Manihot esculenta', description => $description}],
    'Real CSV reader keeps exact scientific identity, Unicode, quotes, description and row number');
my %environment = %ENV;
for my $locale (qw(default en uk es ar)) {
    subtest "$locale parser messages preserve scientific contracts" => sub {
        my $i18n = $locale eq 'default' ? undef : SGN::I18N->new(locale => $locale, catalog_root => $catalog_root);
        is_deeply(normalized(parser($valid, $i18n)->parse()), $baseline, 'All parsed columns/data/values/metadata equal the original English contract');
        my $missing_result = parser($missing, $i18n)->parse();
        my $missing_error = message($locale, 'file.parse.required_column', {column => 'species_name'});
        is_deeply($missing_result->{errors}, [$missing_error], 'Missing required header uses exact canonical name and locale message');
        is_deeply(parser($blank, $i18n)->parse()->{errors}, [message($locale, 'file.parse.required_value', {column => 'species_name', row => 2})],
            'Blank required value uses the same header and original row number');
        is_deeply(parser($duplicate, $i18n)->parse()->{errors}, [message($locale, 'file.parse.duplicate_header', {header => 'accession_name', column => 3})],
            'Duplicate header retains canonical token and one-based column position');
        is_deeply(parser($repeat, $i18n)->parse()->{errors}, [message($locale, 'file.parse.duplicate_value', {column => 'accession_name', value => $stock, rows => '2,3'})],
            'Duplicate-value error retains complete literal biological identity and row numbers');
        is_deeply(parser($unsupported, $i18n)->parse()->{errors}, [message($locale, 'file.parse.no_plugin', {file => $unsupported, type => 'no_parser'})],
            'Unsupported extension preserves filename and original type token');
        my $absent = "$dir/Опис_missing.csv";
        is_deeply(parser($absent, $i18n)->parse()->{errors}, [message($locale, 'file.parse.missing', {file => $absent})],
            'Missing filename remains plain Unicode data');
        my $wrong_type = parser($valid, $i18n, type => 'no_parser');
        is_deeply(CXGN::File::Parse::Plugin::Plain->parse($wrong_type)->{errors}, [message($locale, 'file.parse.plain_type', {type => 'no_parser'})],
            'Actual plain plugin retains invalid-type early return');
        is_deeply(CXGN::File::Parse::Plugin::Spreadsheet->parse($wrong_type)->{errors}, [message($locale, 'file.parse.spreadsheet_type', {type => 'no_parser'})],
            'Actual spreadsheet plugin retains invalid-type early return');
        is_deeply(parser($unknown, $i18n)->parse()->{additional_columns}, ['CO_334:Опис<field>'], 'CV-like additional column stays canonical data');
        my $schema = bless {}, 'Local::FileParseI18N::Schema';
        my $stock_parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $unknown, editable_stock_props => [],
            defined($i18n) ? (i18n => $i18n) : ());
        $stock_parser->load_plugin('AccessionsGeneric');
        ok(!$stock_parser->_validate_with_plugin(), 'Actual accession role rejects unknown columns before schema access');
        is_deeply($stock_parser->get_parse_errors(), {error_messages => [message($locale, 'accessions.parse.unknown_columns', {columns => 'CO_334:Опис<field>'})]},
            'Accession validator keeps the same translator and literal CV-like data');
        my $missing_stock_parser = CXGN::Stock::ParseUpload->new(chado_schema => $schema, filename => $missing, editable_stock_props => [],
            defined($i18n) ? (i18n => $i18n) : ());
        $missing_stock_parser->load_plugin('AccessionsGeneric');
        ok(!$missing_stock_parser->_validate_with_plugin(), 'Missing-header accession validation retains original early return');
        is_deeply($missing_stock_parser->get_parse_errors(), {error_messages => [$missing_error]}, 'File-parser error propagates unchanged through accession validation');
    };
}
my $ok = eval { parser($valid, Local::FileParseI18N::Invalid->new); 1 };
ok(!$ok && $@ =~ /must implement p/, 'Invalid presentation object is rejected at injection boundary');
my %keys = map {$_ => 1} (keys %environment, keys %ENV);
ok(!grep({!exists($environment{$_}) || !exists($ENV{$_}) || $environment{$_} ne $ENV{$_}} keys %keys), 'Presentation does not mutate process environment');
done_testing;
