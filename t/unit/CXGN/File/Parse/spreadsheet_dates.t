
# Date cells in an uploaded spreadsheet come back as ISO 8601 dates, whatever number format the cell
# displays them with, while numbers and text are returned as before.

use strict;
use warnings;

use Test::More;
use File::Temp qw(tempdir);
use Excel::Writer::XLSX;
use Spreadsheet::ParseXLSX;
use Spreadsheet::ParseODS;
use Archive::Zip qw(AZ_OK COMPRESSION_STORED COMPRESSION_DEFLATED);
use CXGN::File::Parse;
use CXGN::File::Spreadsheet qw(cell_value);
use CXGN::Phenotypes::StorePhenotypes;
use Spreadsheet::WriteExcel;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimpleGeneric;

my $dir = tempdir(CLEANUP => 1);
my $file = "$dir/dates.xlsx";

my $workbook = Excel::Writer::XLSX->new($file);
my $sheet = $workbook->add_worksheet();
my $us_date = $workbook->add_format(num_format => 'm/d/yyyy');
my $short_date = $workbook->add_format(num_format => 'd-mmm-yy');
my $date_time = $workbook->add_format(num_format => 'm/d/yyyy h:mm');
my $clock = $workbook->add_format(num_format => 'h:mm');
my $elapsed = $workbook->add_format(num_format => '[h]:mm');

$sheet->write_row(0, 0, [ 'observationunit_name', 'us_date', 'short_date', 'date_time', 'number', 'text', 'time', 'duration', 'month_only', 'padded', 'filled', 'conditional' ]);
$sheet->write_string(1, 0, 'plot1');
$sheet->write_date_time(1, 1, '2026-03-24T', $us_date);
$sheet->write_date_time(1, 2, '2026-03-04T', $short_date);
$sheet->write_date_time(1, 3, '2026-03-24T14:30:05', $date_time);
$sheet->write_number(1, 4, 42.5);
$sheet->write_string(1, 5, '3/24/2026');
$sheet->write_number(1, 6, 0.5, $clock);
$sheet->write_number(1, 7, 1.5, $elapsed);
$sheet->write_date_time(1, 8, '2026-03-24T', $workbook->add_format(num_format => 'mm'));
$sheet->write_number(1, 9, 42, $workbook->add_format(num_format => '0_d'));
$sheet->write_number(1, 10, 42, $workbook->add_format(num_format => '0*y'));
$sheet->write_number(1, 11, 42, $workbook->add_format(num_format => '[>=40000]yyyy-mm-dd;0'));
$workbook->close();

my $read_workbook = Spreadsheet::ParseXLSX->new()->parse($file);
my $read_sheet = ($read_workbook->worksheets())[0];
is($read_sheet->get_cell(1, 1)->value(), '3/24/2026', 'the date fixture has US display text');
is(cell_value($read_sheet->get_cell(1, 1), $read_workbook), '2026-03-24', 'the helper converts a date cell');
is(cell_value($read_sheet->get_cell(1, 4), $read_workbook), '42.5', 'the helper preserves a number');
is(cell_value($read_sheet->get_cell(1, 5), $read_workbook), '3/24/2026', 'the helper preserves text');

my $parsed = CXGN::File::Parse->new( file => $file )->parse();
is_deeply($parsed->{errors}, [], 'the spreadsheet parses without errors');

my $row = $parsed->{data}->[0];
is($row->{us_date}, '2026-03-24', 'a date cell formatted m/d/yyyy is returned as an ISO date');
is($row->{short_date}, '2026-03-04', 'a date cell formatted d-mmm-yy is returned as an ISO date');
is($row->{date_time}, '2026-03-24 14:30:05', 'a date and time cell keeps its time of day');
is($row->{number}, '42.5', 'a number is returned unchanged');
is($row->{text}, '3/24/2026', 'text that looks like a date is returned as typed');
is($row->{time}, '12:00', 'a time of day is returned as displayed');
is($row->{duration}, $read_sheet->get_cell(1, 7)->value(), 'a duration longer than a day is returned as displayed');
unlike($row->{duration}, qr/^\d{4}-/, 'a duration is not read as a date');
is($row->{month_only}, '2026-03-24', 'a date shown as a month alone is returned as an ISO date');
unlike($row->{$_}, qr/^\d{4}-/, "a number formatted $_ is not read as a date") for qw(padded filled conditional);
ok(CXGN::Phenotypes::StorePhenotypes::_is_iso_date($row->{$_}), "the converted $_ passes the date-trait check") for qw(us_date short_date date_time);

my $mac_file = "$dir/dates_1904.xlsx";
my $mac_workbook = Excel::Writer::XLSX->new($mac_file);
$mac_workbook->set_1904();
my $mac_sheet = $mac_workbook->add_worksheet();
$mac_sheet->write_row(0, 0, ['observationunit_name', 'date', 'first_day', 'time']);
$mac_sheet->write_string(1, 0, 'plot1');
$mac_sheet->write_date_time(1, 1, '2026-03-24T', $mac_workbook->add_format(num_format => 'm/d/yyyy'));
$mac_sheet->write_number(1, 2, 0, $mac_workbook->add_format(num_format => 'yyyy-mm-dd'));
$mac_sheet->write_number(1, 3, 0.5, $mac_workbook->add_format(num_format => 'h:mm:ss'));
$mac_workbook->close();
my $mac_parsed = CXGN::File::Parse->new(file => $mac_file)->parse();
is($mac_parsed->{data}[0]{date}, '2026-03-24', 'the workbook selects the 1904 date epoch');
is($mac_parsed->{data}[0]{first_day}, '1904-01-01', 'day 0 of the 1904 epoch is a date, not a time');
is($mac_parsed->{data}[0]{time}, '12:00:00', 'a time of day in a 1904 workbook is returned as displayed');

# The older .xls format goes through Spreadsheet::ParseExcel.
my $xls_file = "$dir/dates.xls";
my $xls_workbook = Spreadsheet::WriteExcel->new($xls_file);
my $xls_sheet = $xls_workbook->add_worksheet();
$xls_sheet->write_row(0, 0, ['observationunit_name', 'date', 'date_time', 'number', 'time', 'decimal']);
$xls_sheet->write_string(1, 0, 'plot1');
$xls_sheet->write_date_time(1, 1, '2026-03-24T', $xls_workbook->add_format(num_format => 'm/d/yyyy'));
$xls_sheet->write_date_time(1, 2, '2026-03-24T14:30:05', $xls_workbook->add_format(num_format => 'm/d/yyyy h:mm'));
$xls_sheet->write_number(1, 3, 42.5);
$xls_sheet->write_number(1, 4, 0.5, $xls_workbook->add_format(num_format => 'h:mm'));
$xls_sheet->write_number(1, 5, 46105.5, $xls_workbook->add_format(num_format => '0.00'));
$xls_workbook->close();
my $xls_parsed = CXGN::File::Parse->new(file => $xls_file)->parse();
is_deeply($xls_parsed->{errors}, [], 'the .xls spreadsheet parses without errors');
is($xls_parsed->{data}[0]{date}, '2026-03-24', 'an .xls date cell is returned as an ISO date');
is($xls_parsed->{data}[0]{date_time}, '2026-03-24 14:30:05', 'an .xls date and time cell keeps its time of day');
is($xls_parsed->{data}[0]{number}, '42.5', 'an .xls number is returned unchanged');
is($xls_parsed->{data}[0]{time}, '12:00', 'an .xls time of day is returned as displayed');
is($xls_parsed->{data}[0]{decimal}, '46105.50', 'an .xls number in a decimal format is not read as a date');

# ODS stores the date and the displayed text separately in content.xml.
my $ods_file = "$dir/dates.ods";
my $ods = Archive::Zip->new();
my $mimetype = $ods->addString('application/vnd.oasis.opendocument.spreadsheet', 'mimetype');
$mimetype->desiredCompressionMethod(COMPRESSION_STORED);
$ods->addString(<<'XML', 'styles.xml');
<?xml version="1.0" encoding="UTF-8"?>
<office:document-styles xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" office:version="1.2">
  <office:styles><style:style style:name="Default" style:family="table-cell"/></office:styles>
</office:document-styles>
XML
$ods->addString(<<'XML', 'META-INF/manifest.xml');
<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
  <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
</manifest:manifest>
XML
$ods->addString(<<'XML', 'content.xml');
<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.2">
  <office:body><office:spreadsheet><table:table table:name="Dates">
    <table:table-row>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>observationunit_name</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>date</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>date_time</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>number</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>text</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>fraction</text:p></table:table-cell>
    </table:table-row>
    <table:table-row>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>plot1</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="date" office:date-value="2026-03-24"><text:p>3/24/2026</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="date" office:date-value="2026-03-24T14:30:05"><text:p>3/24/2026 14:30</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="float" office:value="42.5"><text:p>42.50</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="string"><text:p>3/24/2026</text:p></table:table-cell>
      <table:table-cell table:style-name="Default" office:value-type="date" office:date-value="2026-03-24T14:30:05.123"><text:p>3/24/2026 14:30</text:p></table:table-cell>
    </table:table-row>
  </table:table></office:spreadsheet></office:body>
</office:document-content>
XML
# Office suites deflate every member except mimetype, and Spreadsheet::ParseODS cannot read stored ones.
$_->desiredCompressionMethod($_->fileName() eq 'mimetype' ? COMPRESSION_STORED : COMPRESSION_DEFLATED) for $ods->members();
is($ods->writeToFileNamed($ods_file), AZ_OK, 'the ODS fixture is written');
my $ods_workbook = Spreadsheet::ParseODS->new()->parse($ods_file);
my $ods_sheet = ($ods_workbook->worksheets())[0];
my $ods_cell = $ods_sheet->get_cell(1, 1);
is($ods_cell->type(), 'date', 'ODS exposes the date type');
is($ods_cell->value(), '3/24/2026', 'ODS exposes the display text');
is($ods_cell->unformatted(), '2026-03-24', 'ODS exposes the underlying ISO date');
is(cell_value($ods_cell, $ods_workbook), '2026-03-24', 'the helper reads the underlying ODS date');
my $midnight_cell = Spreadsheet::ParseODS::Cell->new(
    type => 'date', unformatted => '2026-03-24T00:00:00', value => '3/24/2026'
);
is(cell_value($midnight_cell, $ods_workbook), '2026-03-24', 'ODS midnight is a plain date like an integer Excel date');
my $ods_parsed = CXGN::File::Parse->new(file => $ods_file)->parse();
is_deeply($ods_parsed->{errors}, [], 'the ODS spreadsheet parses without errors');
my $ods_row = $ods_parsed->{data}[0];
is($ods_row->{date}, '2026-03-24', 'an ODS date is returned as ISO');
is($ods_row->{date_time}, '2026-03-24 14:30:05', 'an ODS date keeps its time of day');
is($ods_row->{number}, '42.50', 'an ODS number keeps its ordinary value');
is($ods_row->{text}, '3/24/2026', 'ODS text is unchanged');
is($ods_row->{fraction}, '2026-03-24 14:30:05', 'an ODS time with a fraction of a second is returned to the whole second');
ok(CXGN::Phenotypes::StorePhenotypes::_is_iso_date($ods_row->{$_}), "the converted ODS $_ passes the date-trait check") for qw(date date_time fraction);
my $ods_phenotypes = CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimpleGeneric->new()->parse($ods_file, 0, 'plots');
ok(!$ods_phenotypes->{error}, 'the generic phenotype parser accepts ODS');
is($ods_phenotypes->{data}{plot1}{date}[0][0], '2026-03-24', 'the generic phenotype parser returns an ODS date as an ISO date');

done_testing();
