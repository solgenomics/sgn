use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;
use File::Temp qw(tempdir);
use Excel::Writer::XLSX;
use Text::CSV;
use Archive::Zip qw(AZ_OK);

use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimpleGeneric;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheet;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetCSV;
use CXGN::Phenotypes::ParseUpload::Plugin::DataCollectorSpreadsheet;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetAssociatedImages;
use CXGN::Phenotypes::ParseUpload::Plugin::AnalysisPhenotypeSpreadsheetCSV;
use CXGN::Phenotypes::ParseUpload::Plugin::PhenotypeSpreadsheetSimple;

# Real files and parse() methods; no database validation or storage. Marker
# strings are synthetic parser inputs, not field data.
my $directory = tempdir(CLEANUP => 1);
my $trait = 'synthetic_marker|TEST:0001';
my $timestamp = '2030-05-20 12:00:00+0000';
my @markers = (['dot', '.'], ['NA', 'NA'], ['blank', ''], ['zero', '0']);
my @formats = (
    ['PhenotypeSpreadsheetSimpleGeneric', 'csv', 0, 1, 0, 1],
    ['PhenotypeSpreadsheet', 'xlsx', 6, 9, 0, 1],
    ['PhenotypeSpreadsheetCSV', 'csv', 0, 15, 11, 0],
    ['DataCollectorSpreadsheet', 'xlsx', 0, 6, 0, 0],
    ['PhenotypeSpreadsheetAssociatedImages', 'xlsx', 0, 2, 0, 0],
    ['AnalysisPhenotypeSpreadsheetCSV', 'csv', 0, 1, 0, 0],
    ['PhenotypeSpreadsheetSimple', 'xlsx', 0, 1, 0, 1],
);

for my $format (@formats) {
    my ($plugin, $extension, $header_row, $trait_column, $unit_column, $nested) = @$format;
    subtest $plugin => sub {
        for my $with_timestamp (0, 1) {
            my $file = "$directory/${plugin}_${with_timestamp}.$extension";
            my @rows;
            $rows[$header_row] = [map { "metadata_$_" } 0 .. $trait_column];
            $rows[$header_row][$unit_column] = 'plot_name';
            $rows[$header_row][$trait_column] = $trait;
            if ($plugin eq 'PhenotypeSpreadsheet') {
                $rows[3][3] = 'CRD';
                $rows[4][1] = '[]';
            }
            if ($plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
                $rows[0] = [qw(observationunit_name observationvariable_name phenotype_value phenotype_timestamp image_name username)];
            }
            for my $index (0 .. $#markers) {
                my ($label, $value) = @{$markers[$index]};
                my $row = $header_row + $index + 1;
                my $unit = "synthetic_$label";
                $rows[$row][$unit_column] = $unit;
                $rows[$row][$trait_column] = $with_timestamp ? "$value,$timestamp" : $value;
                if ($plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
                    $rows[$row] = [$unit, $trait, $value,
                        $with_timestamp ? $timestamp : '', "$unit.png", 'synthetic_operator'];
                }
            }
            write_file($file, \@rows, $plugin eq 'DataCollectorSpreadsheet' ? 8 : 1);

            my ($schema, $image_zip, @image_mocks);
            if ($plugin eq 'PhenotypeSpreadsheetAssociatedImages') {
                ($schema, @image_mocks) = image_lookup_stubs();
                $image_zip = "$directory/images_${with_timestamp}.zip";
                my $archive = Archive::Zip->new;
                for my $marker (@markers) {
                    $archive->addString('Synthetic text member; not an image.',
                        "synthetic_$marker->[0].png");
                }
                die "Cannot write $image_zip" unless $archive->writeToFileNamed($image_zip) == AZ_OK;
            }
            my $class = "CXGN::Phenotypes::ParseUpload::Plugin::$plugin";
            if ($image_zip) {
                # The existing validator rejects an absent phenotype cell,
                # while a formatted blank cell exists and can pass validation.
                # Keep the formatted blank in the separate parse() fixture.
                my $missing_cell_file = "$directory/${plugin}_${with_timestamp}_missing_cell.xlsx";
                write_file($missing_cell_file, \@rows, 1, [3, 2]);
                my $validation = eval { $class->new->validate($missing_cell_file, $with_timestamp, 'plots', $schema, $image_zip) };
                my $validation_exception = $@;
                ok(!$validation_exception && ref($validation) eq 'HASH'
                        && ($validation->{error} || '') =~ /^No phenotype value on row 3!$/,
                    "image spreadsheet still rejects a missing phenotype cell (timestamps=$with_timestamp)")
                    or diag($validation_exception || (ref($validation) eq 'HASH' && $validation->{error})
                        || 'Validator did not return the existing missing phenotype-value error');

                my @valid_rows = map { $_ ? [@$_] : undef } @rows;
                $valid_rows[3][2] = 'NA';
                my $valid_file = "$directory/${plugin}_${with_timestamp}_nonblank.xlsx";
                write_file($valid_file, \@valid_rows, 1);
                $validation = eval { $class->new->validate($valid_file, $with_timestamp, 'plots', $schema, $image_zip) };
                $validation_exception = $@;
                ok(!$validation_exception && defined($validation) && !ref($validation) && $validation == 1,
                    "image spreadsheet with dot, NA and zero validates (timestamps=$with_timestamp)")
                    or diag($validation_exception || (ref($validation) eq 'HASH' && $validation->{error})
                        || 'Validator did not accept the synthetic XLSX and ZIP');
            }
            my $result = eval { $class->new->parse($file, $with_timestamp, 'plots', $schema, $image_zip) };
            my $exception = $@;
            ok(!$exception && $result && !$result->{error},
                "parse succeeds (timestamps=$with_timestamp)")
                or diag($exception || ($result && $result->{error}) || 'Parser returned no result');
            next unless $result;
            is_deeply([sort @{$result->{units} || []}],
                [sort map { 'synthetic_'.$_->[0] } @markers], 'all input units are retained');
            for my $marker (@markers) {
                my ($label, $value) = @$marker;
                my $measurements = $result->{data}{"synthetic_$label"}{$trait};
                my $measurement = $nested ? ($measurements || [])->[0] : $measurements;
                is_deeply($measurement ? [@$measurement[0, 1]] : undef,
                    [$value, $with_timestamp ? $timestamp : ''],
                    "$label survives parsing (timestamps=$with_timestamp)");
            }
        }
    };
}

# AssociatedImages requires stock/project IDs and uploads images inside parse().
# Stub only those services: XLSX decoding and marker extraction remain real.
# validate() checks a real ZIP containing named text members, not image pixels.
# No database, image decoding, conversion, or upload is tested by this suite.
sub image_lookup_stubs {
    my $statement = Test::MockObject->new;
    my @lookup_rows = map { ["synthetic_$markers[$_][0]", $_ + 1, 1] } 0 .. $#markers;
    $statement->mock(execute => sub { return 1 });
    $statement->mock(fetchrow_array => sub { return @{shift @lookup_rows || []} });
    my $schema = Test::MockObject->new;
    $schema->mock(storage => sub { $schema });
    $schema->mock(dbh => sub { $schema });
    $schema->mock(prepare => sub { $statement });
    my $term = Test::MockObject->new;
    $term->mock(cvterm_id => sub { 1 });
    my $cvterm = Test::MockModule->new('SGN::Model::Cvterm');
    $cvterm->mock(get_cvterm_row => sub { $term });
    my $transform = Test::MockModule->new('CXGN::List::Transform');
    $transform->mock(transform => sub { return {transform => [1 .. scalar @markers]} });
    my $validator = Test::MockModule->new('CXGN::List::Validate');
    $validator->mock(validate => sub { return {missing => []} });
    my $image_object = Test::MockObject->new;
    $image_object->mock(upload_phenotypes_associated_images_zipfile => sub {
        return {return => {map { $_ => 900 + $_ } 1 .. scalar @markers}};
    });
    my $image = Test::MockModule->new('SGN::Image');
    $image->mock(new => sub { $image_object });
    return ($schema, $cvterm, $transform, $validator, $image);
}

sub write_file {
    my ($file, $rows, $sheet_count, $omitted_cell) = @_;
    if ($file =~ /\.csv$/) {
        my $csv = Text::CSV->new({binary => 1, eol => "\n"});
        open(my $handle, '>', $file) or die "Cannot write $file: $!";
        for my $row (@$rows) {
            $csv->print($handle, [map { defined($_) ? $_ : '' } @{$row || []}])
                or die $csv->error_diag;
        }
        close($handle) or die "Cannot close $file: $!";
    }
    else {
        my $workbook = Excel::Writer::XLSX->new($file);
        my $worksheet;
        for (1 .. $sheet_count) { $worksheet = $workbook->add_worksheet(); }
        my $blank_format = $workbook->add_format(num_format => '@');
        for my $row (0 .. $#$rows) {
            next unless $rows->[$row];
            for my $column (0 .. $#{$rows->[$row]}) {
                next if $omitted_cell && $row == $omitted_cell->[0] && $column == $omitted_cell->[1];
                next unless defined $rows->[$row][$column];
                $worksheet->write_string($row, $column, $rows->[$row][$column], $blank_format);
            }
        }
        $workbook->close();
    }
}

done_testing();
