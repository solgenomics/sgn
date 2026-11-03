use strict;
use warnings;
use Test::More;
use Bio::Chado::Schema;
use CXGN::Trial::ParseUpload;
use CXGN::Trial::AccessionChange;
use CXGN::File::Parse;
use File::Temp qw(tempfile);
use Excel::Writer::XLSX;
use JSON qw(encode_json);

# Pure caller/summary checks: the real schema object refuses any attempted DB
# connection, so this cannot use the coordinator's exclusive PostgreSQL slot.
my $schema=Bio::Chado::Schema->connect(sub {die 'Read-only contract probe must not access PostgreSQL'});
sub generic {
    return CXGN::File::Parse->new(file=>$_[0],required_columns=>[qw(plot_name accession_name)],optional_columns=>[qw(new_plot_name seedlot_name free_text)],unique_only_columns=>['plot_name'],column_aliases=>{plot_name=>['plot name']})->parse;
}
sub csv {
    my($content)=@_;my($fh,$path)=tempfile(SUFFIX=>'.csv',UNLINK=>1);print $fh $content;close$fh;return generic($path);
}
sub xlsx {
    my($rows)=@_;my($fh,$path)=tempfile(SUFFIX=>'.xlsx',UNLINK=>1);close$fh;my$book=Excel::Writer::XLSX->new($path);my$sheet=$book->add_worksheet;
    for my$r(0..$#$rows){for my$c(0..$#{$rows->[$r]}){$sheet->write_string($r,$c,$rows->[$r][$c]);}}
    $book->close;return generic($path);
}
for my $field (qw(not_planted rejected reject_reason)) {
    my ($fh,$path)=tempfile(SUFFIX=>'.csv',UNLINK=>1);
    print $fh "plot_name,accession_name,$field\nP1,A1,1\n";close $fh;
    my $upload=CXGN::Trial::ParseUpload->new(chado_schema=>$schema,filename=>$path,trial_id=>'1');
    $upload->load_plugin('TrialChangePlotAccessions');
    ok(!$upload->_validate_with_plugin,'unsupported status column is refused before any database access');
    like(join(' ',@{$upload->get_parse_errors->{error_messages}}),qr/Unsupported correction column.*\Q$field\E/,'unsupported column is named');
}
for my $parsed(csv("plot_name,accession_name,new_plot_name,seedlot_name,free_text\nP1,0,0,0,0\n"),xlsx([[qw(plot_name accession_name new_plot_name seedlot_name free_text)],[qw(P1 0 0 0 0)]])) {
    is_deeply($parsed->{errors},[],'generic identity input is valid');
    is_deeply([@{$parsed->{data}[0]}{qw(accession_name new_plot_name seedlot_name free_text)}],[qw(0 0 0 0)],'generic CSV/XLSX cells retain literal zero');
    my $upload=CXGN::Trial::ParseUpload->new(chado_schema=>$schema,filename=>'unused.csv',trial_id=>'1');
    $upload->load_plugin('TrialChangePlotAccessions');
    $upload->_set_parsed_data({parsed=>$parsed->{data}});
    $upload->_parse_with_plugin;
    my $mapped=$upload->_parsed_data->{P1};
    is($mapped->{new_accession_name},'0','accession zero reaches service input');
    is($mapped->{seedlot_name},'0','seedlot zero reaches service input');
    ok(!exists($mapped->{free_text}),'additional generic text is not promoted to an unsupported correction field');
    is($mapped->{new_plot_name},'0','optional new plot name zero reaches service input');
}
for my $parsed(csv("plot_name,Plot Name,accession_name\nP1,P1,A1\n"),xlsx([[qw(plot_name), 'Plot Name',qw(accession_name)],[qw(P1 P1 A1)]])) {
    like(join(' ',@{$parsed->{errors}||[]}),qr/duplicated/,'canonical/alias duplicate headers refused');
}
my $plan={map {$_=>[]} qw(changes unchanged replicates renames not_renamed entry_numbers checks seedlots warnings)};
$plan->{renames}=[{stock_id=>1,type=>'plot',old_name=>'P1',new_name=>'Q1'}];
$plan->{affected_plots}=['P1'];$plan->{affected_project_ids}=[1];
$plan->{phenotypes_to_delete}={phenotype_ids=>[],nd_experiment_ids=>[]};$plan->{plots_with_phenotypes}=0;
my $summary=CXGN::Trial::AccessionChange->new(schema=>$schema,trial_id=>1)->summary($plan);
is_deeply($summary->{affected_plots},['Q1'],'server exports final affected plot names for the current JS contract');
diag('Actual server summary: '.encode_json($summary));
$plan->{renames}=[{stock_id=>1,type=>'plot',old_name=>'A',new_name=>'B'},{stock_id=>2,type=>'plot',old_name=>'B',new_name=>'C'}];
$plan->{affected_plots}=['A','B'];
$summary=CXGN::Trial::AccessionChange->new(schema=>$schema,trial_id=>1)->summary($plan);
is_deeply($summary->{affected_plots},['B','C'],'rename chains map each original name once');
$plan->{renames}=[{stock_id=>1,type=>'plot',old_name=>'A',new_name=>'0'}];$plan->{affected_plots}=['A'];
$summary=CXGN::Trial::AccessionChange->new(schema=>$schema,trial_id=>1)->summary($plan);
is_deeply($summary->{affected_plots},['0'],'final label contract retains a literal zero name');
done_testing;
