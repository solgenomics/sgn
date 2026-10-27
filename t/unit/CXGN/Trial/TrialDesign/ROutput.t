package main;
use strict;
use warnings;
use utf8;
use Test::More;
use Scalar::Util qw(refaddr);
use Encode qw(encode);
use JSON::XS;
use R::YapRI::Data::Matrix;
use CXGN::Trial::TrialDesign::ROutput qw(read_rbase_utf8);

my $json = JSON::XS->new->utf8->canonical;
my $read_result;
my @read_arguments;
my $read_calls = 0;
my $original_data_setter = \&R::YapRI::Data::Matrix::set_data;
my $original_columns_setter = \&R::YapRI::Data::Matrix::set_colnames;
my $original_rows_setter = \&R::YapRI::Data::Matrix::set_rownames;

sub matrix {
    my (%args) = @_;
    return R::YapRI::Data::Matrix->new({name => 'unit_result', %args});
}

sub snapshot {
    my ($matrix) = @_;
    return $json->encode({data => $matrix->get_data(), columns => $matrix->get_colnames(),
                          rows => $matrix->get_rownames(), rown => $matrix->get_rown(), coln => $matrix->get_coln()});
}

sub read_result {
    my ($matrix, @arguments) = @_;
    no warnings 'redefine';
    local *R::YapRI::Data::Matrix::read_rbase = sub {
        my $class = shift;
        is($class, 'R::YapRI::Data::Matrix', 'original reader receives its actual Matrix class');
        @read_arguments = @_;
        $read_calls++;
        return $matrix;
    };
    return read_rbase_utf8(@arguments);
}

subtest 'UTF-8 output data and metadata use public setters without touching input arrays' => sub {
    my $text = 'Дослід_试验_الأصل';
    my $data = [encode('UTF-8', $text), 7, '001'];
    my $columns = [encode('UTF-8', 'Назва'), 'count', 'code'];
    my $rows = [encode('UTF-8', 'Рядок')];
    my $matrix = matrix(rown => 1, coln => 3, data => $data, colnames => $columns, rownames => $rows);
    my $input = matrix(rown => 1, coln => 1, data => [$text]);
    my $input_before = snapshot($input);
    my ($data_sets, $column_sets, $row_sets) = (0, 0, 0);
    no warnings 'redefine';
    local *R::YapRI::Data::Matrix::set_data = sub { $data_sets++; $original_data_setter->(@_); };
    local *R::YapRI::Data::Matrix::set_colnames = sub { $column_sets++; $original_columns_setter->(@_); };
    local *R::YapRI::Data::Matrix::set_rownames = sub { $row_sets++; $original_rows_setter->(@_); };
    my $returned = read_result($matrix, $input, 'r_block', 'crd');
    is(refaddr($returned), refaddr($matrix), 'same newly returned object');
    isa_ok($returned, 'R::YapRI::Data::Matrix');
    is_deeply([$returned->get_rown(), $returned->get_coln()], [1, 3], 'dimensions preserved');
    is_deeply($returned->get_data(), [$text, 7, '001'], 'data order and values preserved');
    is_deeply($returned->get_colnames(), ['Назва', 'count', 'code'], 'column names decoded');
    is_deeply($returned->get_rownames(), ['Рядок'], 'row names decoded');
    is_deeply([$returned->get_column('Назва')], [$text], 'public column lookup returns characters');
    is_deeply([$data_sets, $column_sets, $row_sets], [1, 1, 1], 'only changed arrays have setters');
    is($json->encode($returned->get_data()), $json->encode([$text, 7, '001']), 'Unicode and JSON number/string types preserved');
    ok(!utf8::is_utf8($data->[0]), 'old data array remains raw bytes');
    is($data->[0], encode('UTF-8', $text), 'old byte value is not consumed by Encode');
    ok(!utf8::is_utf8($columns->[0]) && !utf8::is_utf8($rows->[0]), 'old metadata arrays stay unchanged');
    is(snapshot($input), $input_before, 'input Matrix was not normalized');
    is(refaddr($read_arguments[0]), refaddr($input), 'original input object passed unchanged');
    is_deeply([@read_arguments[1, 2]], ['r_block', 'crd'], 'original reader arguments preserved');
};

subtest 'already flagged characters and numeric ASCII undef values retain exact JSON types' => sub {
    my $legitimate = 'Ã©';
    my $matrix = matrix(rown => 1, coln => 6, data => [$legitimate, 7, 2.5, '007', undef, 'plain']);
    my $before = snapshot($matrix);
    my $data_address = refaddr($matrix->get_data());
    my $sets = 0;
    no warnings 'redefine';
    local *R::YapRI::Data::Matrix::set_data = sub { $sets++; $original_data_setter->(@_); };
    local *R::YapRI::Data::Matrix::set_colnames = sub { $sets++; $original_columns_setter->(@_); };
    local *R::YapRI::Data::Matrix::set_rownames = sub { $sets++; $original_rows_setter->(@_); };
    read_result($matrix, 'input', 'r_block', 'crd');
    is(snapshot($matrix), $before, 'flagged literal and ASCII/numeric/null representations exact');
    is($matrix->get_data()->[0], $legitimate, 'legitimate flagged text is not repaired heuristically');
    ok(utf8::is_utf8($matrix->get_data()->[0]), 'character flag remains set');
    is($json->encode($matrix->get_data()), $json->encode([$legitimate, 7, 2.5, '007', undef, 'plain']), 'JSON numeric and string types remain exact');
    is($sets, 0, 'no setters for already normalized or ASCII-only arrays');
    is(refaddr($matrix->get_data()), $data_address, 'unchanged array is retained');
};

subtest 'ASCII-only identity validation preserves numerical input and output types' => sub {
    my $matrix = matrix(rown => 2, coln => 2, data => [1, 7, 2, 8], colnames => ['plots', 'trt']);
    my $allowed = [7, 8];
    my $before = snapshot($matrix);
    my $allowed_before = $json->encode($allowed);
    my $address = refaddr($matrix->get_data());
    read_result($matrix, 'input', 'r_block', 'crd', {trt => $allowed});
    is(snapshot($matrix), $before, 'ASCII numeric matrix remains exact');
    is($json->encode($allowed), $allowed_before, 'expected values are not stringified in their input array');
    is(refaddr($matrix->get_data()), $address, 'ASCII-only data is not reset or reindexed');
    is_deeply(\@read_arguments, ['input', 'r_block', 'crd'], 'optional identity guard is not forwarded to original reader');
};

subtest 'malformed bytes anywhere fail before changing a Matrix or its arrays' => sub {
    for my $field (qw(data colnames rownames)) {
        for my $invalid ("\xff", "\xc0\xaf", "\xd0") {
            my %args = (rown => 1, coln => 2, data => [encode('UTF-8', 'Дослід'), 7],
                        colnames => ['trt', 'plots'], rownames => ['1']);
            $args{$field}->[0] = $invalid;
            my $matrix = matrix(%args);
            my $before = snapshot($matrix);
            my @addresses = map {refaddr($_)} ($matrix->get_data(), $matrix->get_colnames(), $matrix->get_rownames());
            my $error;
            eval { read_result($matrix, 'input', 'r_block', 'crd'); 1 } or $error = $@;
            like($error || '', qr/UTF-8/, 'malformed output bytes fail strictly');
            is(snapshot($matrix), $before, 'all data and metadata remain untouched after failure');
            is_deeply([map {refaddr($_)} ($matrix->get_data(), $matrix->get_colnames(), $matrix->get_rownames())], \@addresses, 'no array is replaced on failure');
        }
    }
};

subtest 'changed whitespace or unknown identities fail without repair or partial decoding' => sub {
    for my $wrong ('Alpha Beta', 'Unknown stock') {
        my $matrix = matrix(rown => 2, coln => 1, data => [$wrong, encode('UTF-8', 'Дослід')], colnames => ['trt']);
        my $before = snapshot($matrix);
        my $error;
        eval {read_result($matrix, 'input', 'r_block', 'crd', {trt => ['Alpha  Beta', 'Дослід']}); 1} or $error = $@;
        like($error || '', qr/changed or unknown stock identity/, 'altered identity rejected');
        is(snapshot($matrix), $before, 'output remains untouched instead of repairing whitespace');
        ok(!utf8::is_utf8($matrix->get_data()->[1]), 'valid bytes are not partially committed before identity failure');
    }
    my $legitimate = 'Ã©';
    my $matrix = matrix(rown => 1, coln => 1, data => [$legitimate], colnames => ['trt']);
    read_result($matrix, 'input', 'r_block', 'crd', {trt => [$legitimate]});
    is($matrix->get_data()->[0], $legitimate, 'legitimate flagged identity passes exact membership');
};

subtest 'identity guards reject missing ambiguous or malformed expected columns' => sub {
    for my $columns (['other', 'plots'], ['trt', 'trt']) {
        my $matrix = matrix(rown => 1, coln => 2, data => ['known', 'known'], colnames => $columns);
        my $error;
        eval {read_result($matrix, 'input', 'r_block', 'crd', {trt => ['known']}); 1} or $error = $@;
        like($error || '', qr/missing or ambiguous/, 'guard requires one exact output column');
    }
    for my $guard ([], {trt => 'known'}, {trt => [undef]}, {trt => [{}]}) {
        my $matrix = matrix(rown => 1, coln => 1, data => ['known'], colnames => ['trt']);
        my $error;
        eval {read_result($matrix, 'input', 'r_block', 'crd', $guard); 1} or $error = $@;
        like($error || '', qr/R output expected/, 'invalid identity contract fails explicitly');
    }
};

{
    package Local::ROutputNoExecutionBlock;
    sub new { bless {commands => []}, shift }
    sub add_command { push @{$_[0]->{commands}}, $_[1] }
    sub run_block { 1 }
}

subtest 'actual CRD callsite normalizes returned stocks and checks original identity' => sub {
    require CXGN::Trial::TrialDesign;
    my @stocks = ('Дослід_试验_الأصل', 'Сорт_已更新_المصدر');
    my $output = matrix(rown => 2, coln => 3, data => [1, 1, encode('UTF-8', $stocks[0]), 2, 1, encode('UTF-8', $stocks[1])], colnames => ['plots', 'r', 'trt']);
    my $input_data;
    my $block = Local::ROutputNoExecutionBlock->new;
    no warnings 'redefine';
    local *R::YapRI::Base::new = sub {bless {}, 'R::YapRI::Base'};
    local *R::YapRI::Base::create_block = sub {$block};
    local *R::YapRI::Data::Matrix::send_rbase = sub {$input_data = $_[0]->get_data(); return};
    local *R::YapRI::Data::Matrix::read_rbase = sub {$read_calls++; return $output};
    my $trial = CXGN::Trial::TrialDesign->new;
    $trial->set_trial_name('Unit trial');
    $trial->set_stock_list(\@stocks);
    $trial->set_number_of_reps(1);
    $trial->set_design_type('CRD');
    $trial->set_plot_numbering_scheme('consecutive');
    $trial->set_randomization_method('Mersenne-Twister');
    $trial->set_plot_layout_format('zigzag');
    $trial->set_seedlot_hash({$stocks[0] => ['Lot A'], $stocks[1] => ['Lot B']});
    ok($trial->calculate_design(), 'native CRD consumer runs with reader output fixture');
    my $design = $trial->get_design();
    is_deeply([map {$design->{$_}->{stock_name}} sort {$a <=> $b} keys %{$design}], \@stocks, 'native CRD keeps exact Unicode stock identities');
    is_deeply([map {$design->{$_}->{seedlot_name}} sort {$a <=> $b} keys %{$design}], ['Lot A', 'Lot B'], 'normalized stock keys retain seedlot lookup');
    is_deeply($input_data, \@stocks, 'R input matrix remains original character data');
    ok(grep($_ eq 'trt <- stock_data_matrix[1,]', @{$block->{commands}}), 'CRD treatments originate in the original stock matrix');
    is_deeply([map {$design->{$_}->{plot_number}} sort {$a <=> $b} keys %{$design}], [1, 2], 'plot numbering remains canonical');
    my @spaced_stocks = ('Alpha  Beta', 'Known stock');
    $trial->set_stock_list(\@spaced_stocks);
    $output = matrix(rown => 2, coln => 3, data => [1, 1, 'Alpha Beta', 2, 1, 'Known stock'], colnames => ['plots', 'r', 'trt']);
    my $error;
    eval {$trial->calculate_design(); 1} or $error = $@;
    like($error || '', qr/changed or unknown stock identity/, 'native CRD activates exact original identity guard');
    is_deeply($trial->get_stock_list(), \@spaced_stocks, 'failed validation leaves original stock list unchanged');
};

ok($read_calls >= 10, 'tests exercised the original reader boundary');
done_testing();
