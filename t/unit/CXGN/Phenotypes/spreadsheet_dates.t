use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;
use File::Temp qw(tempdir);
use Excel::Writer::XLSX;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheet;
use CXGN::Phenotypes::ParseUpload::Plugin::DataCollectorSpreadsheet;
use CXGN::Phenotypes::ParseUpload::Plugin::FieldBook;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimple;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetAssociatedImages;

my $dir = tempdir(CLEANUP => 1);
my $trait = 'date_trait';
my @fixed_columns = qw(plot_name accession_name plot_number block_number is_a_control rep_number planting_date harvest_date trial_name);
my @formats = (
    ['PhenotypeSpreadsheet', 6, 9, 1],
    ['DataCollectorSpreadsheet', 0, 6, 0],
    ['FieldBook', 0, 2, 1],
    ['PhenotypeSpreadsheetSimple', 0, 1, 1],
    ['PhenotypeSpreadsheetAssociatedImages', 0, 2, 0],
);

for my $format (@formats) {
    my ($plugin, $header_row, $value_column, $nested) = @$format;
    subtest $plugin => sub {
        my $file = "$dir/$plugin.xlsx";
        my $workbook = Excel::Writer::XLSX->new($file);
        my $sheet;
        for (1 .. ($plugin eq 'DataCollectorSpreadsheet' ? 8 : 1)) {
            $sheet = $workbook->add_worksheet();
        }
        my $date_format = $workbook->add_format(num_format => 'm/d/yyyy');
        if ($plugin eq 'FieldBook') {
            $sheet->write_row(0, 0, [qw(plot_name trait value)]);
        }
        elsif ($plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
            $sheet->write_row(0, 0, [qw(observationunit_name observationvariable_name phenotype_value phenotype_timestamp image_name username)]);
        }
        else {
            $sheet->write_row($header_row, 0, [@fixed_columns[0 .. $value_column - 1], $trait]);
        }
        if ($plugin eq 'PhenotypeSpreadsheet') {
            $sheet->write_string(3, 3, 'CRD');
            $sheet->write_string(4, 1, '[]');
        }
        my @labels = qw(date number text);
        for my $index (0 .. $#labels) {
            my $row = $header_row + $index + 1;
            $sheet->write_string($row, 0, "plot_$labels[$index]");
            if ($plugin eq 'FieldBook' || $plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
                $sheet->write_string($row, 1, $trait);
            }
            if ($plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
                $sheet->write_string($row, 4, "plot_$labels[$index].png");
            }
        }
        $sheet->write_date_time($header_row + 1, $value_column, '2026-03-24T', $date_format);
        $sheet->write_number($header_row + 2, $value_column, 42.5);
        $sheet->write_string($header_row + 3, $value_column, '3/24/2026');
        $workbook->close();

        my ($schema, @image_mocks);
        if ($plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
            ($schema, @image_mocks) = image_lookup_stubs();
        }
        my $class = "CXGN::Phenotypes::ParseUpload::Plugin::$plugin";
        my $parser = $class->new();
        if ($plugin ne 'PhenotypeSpreadsheetAssociatedImages') {
            is($parser->validate($file, 0, 'plots'), 1, 'the date spreadsheet validates');
        }
        my $result = $parser->parse($file, 0, 'plots', $schema);
        ok(!$result->{error}, 'the date spreadsheet parses') or diag($result->{error});
        my @expected = ('2026-03-24', '42.5', '3/24/2026');
        for my $index (0 .. $#labels) {
            my $measurement = $result->{data}{"plot_$labels[$index]"}{$trait};
            $measurement = $measurement->[0] if $nested && $measurement;
            is($measurement ? $measurement->[0] : undef, $expected[$index], "$labels[$index] has the expected value");
        }
    };
}

# Image parsing requires stock lookups and an image upload, so stub those side effects.
sub image_lookup_stubs {
    my @rows = (['plot_date', 1, 1], ['plot_number', 2, 1], ['plot_text', 3, 1]);
    my $statement = Test::MockObject->new();
    $statement->mock(execute => sub { 1 });
    $statement->mock(fetchrow_array => sub { return @{shift @rows || []} });
    my $schema = Test::MockObject->new();
    $schema->mock(storage => sub { $schema });
    $schema->mock(dbh => sub { $schema });
    $schema->mock(prepare => sub { $statement });
    my $term = Test::MockObject->new();
    $term->mock(cvterm_id => sub { 1 });
    my $cvterm = Test::MockModule->new('SGN::Model::Cvterm');
    $cvterm->mock(get_cvterm_row => sub { $term });
    my $transform = Test::MockModule->new('CXGN::List::Transform');
    $transform->mock(transform => sub { return {transform => [1, 2, 3]} });
    my $image_object = Test::MockObject->new();
    $image_object->mock(upload_phenotypes_associated_images_zipfile => sub {
        return {return => {1 => 901, 2 => 902, 3 => 903}};
    });
    my $image = Test::MockModule->new('SGN::Image');
    $image->mock(new => sub { $image_object });
    return ($schema, $cvterm, $transform, $image);
}

done_testing();
