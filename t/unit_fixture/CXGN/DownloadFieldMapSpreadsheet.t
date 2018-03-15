use strict;
use lib 't/lib';

use Test::More;
use SGN::Test::Fixture;

use Data::Dumper;
use CXGN::Trial;
use CXGN::Trial::TrialLayoutDownload;

my $test = SGN::Test::Fixture->new();
my $schema = $test->bcs_schema;

open(my $F, "<", '/home/vagrant/cxgn/sgn/t/data/trial/field_coord_upload.csv');
#my $schema = $c->dbic_schema("Bio::Chado::Schema");
my $header = <$F>;
while (<$F>) {
    chomp;
    $_ =~ s/\r//g;
    my ($plot,$row,$col) = split /\t/ ;
    my $rs = $schema->resultset("Stock::Stock")->search({uniquename=> $plot });
    if ($rs->count()== 1) {
    my $r =  $rs->first();
    print STDERR "The plots $plot was found.\n Loading row $row col $col\n";
    $r->create_stockprops({row_number => $row, col_number => $col}, {autocreate => 1});
  }
  else {
    print STDERR "WARNING! $plot was not found in the database.\n"; 
  }
 } 
 
my $trial_layout_download = CXGN::Trial::TrialLayoutDownload->new({
    schema => $schema,
    trial_id => '165',
    data_level => 'plot_fieldMap',
    selected_columns => {
               'accession_name' => 1,
               'col_number' => 1,
               'row_number' => 1
             },
});
my $output = $trial_layout_download->get_layout_output();
my %hash = %{$output->{output}};

is_deeply(\%hash, {
          '2' => {
                   '5' => 'IITA-TMS-IBA011412',
                   '2' => 'TMEB693',
                   '4' => 'IITA-TMS-IBA980581',
                   '1' => 'BLANK',
                   '3' => 'IITA-TMS-IBA980002'
                 },
          '4' => {
                   '2' => 'IITA-TMS-IBA011412',
                   '4' => 'IITA-TMS-IBA980581',
                   '1' => 'TMEB693',
                   '3' => 'IITA-TMS-IBA980002'
                 },
          '1' => {
                   '3' => 'IITA-TMS-IBA30572',
                   '1' => 'IITA-TMS-IBA980581',
                   '2' => 'IITA-TMS-IBA980002',
                   '4' => 'IITA-TMS-IBA011412',
                   '5' => 'TMEB693'
                 },
          '3' => {
                   '3' => 'BLANK',
                   '1' => 'IITA-TMS-IBA30572',
                   '5' => 'IITA-TMS-IBA30572',
                   '2' => 'TMEB419',
                   '4' => 'TMEB419'
                 }
        });
        

done_testing();

       