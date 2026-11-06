use strict;
use warnings;
use utf8;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Fieldbook::TraitInfo;
use Text::CSV;

my $f=SGN::Test::Fixture->new;
my $schema=$f->bcs_schema;
$schema->storage->auto_savepoint(1);
my $trait=$schema->resultset('Cv::Cvterm')->find(70666);
my $xref=$trait->dbxref;
my $db=$xref->db;
my @properties=qw(trait_format trait_default_value trait_minimum trait_maximum trait_details trait_categories);
my %type=map {$_=>SGN::Model::Cvterm->get_cvterm_row($schema,$_,'trait_property')->cvterm_id} @properties;
sub properties {
    my ($values)=@_;
    $schema->resultset('Cv::Cvtermprop')->search({cvterm_id=>$trait->cvterm_id,type_id=>{-in=>[values %type]}})->delete;
    for my $key(keys %$values){$schema->resultset('Cv::Cvtermprop')->create({cvterm_id=>$trait->cvterm_id,type_id=>$type{$key},value=>$values->{$key},rank=>0});}
}
sub fields {
    my $info=CXGN::Fieldbook::TraitInfo->new({chado_schema=>$schema,db_name=>$db->name,trait_accession=>$xref->accession})->get_trait_info($trait->name);
    my $csv=Text::CSV->new({binary=>1});
    return if !$csv->parse($info);
    return [$csv->fields];
}
$schema->txn_begin;
my $ran=eval {
    my %format=(Numerical=>'numeric',Duration=>'numeric',Nominal=>'categorical',Ordinal=>'categorical',Date=>'date',Code=>'text',Text=>'text');
    for my $input(sort keys %format){
        my $categorical=$format{$input} eq 'categorical';
        properties({trait_format=>$input,trait_details=>'Число, межі від нуля',($categorical ? (trait_categories=>'0=Низький/1=Високий') : ())});
        my $row=fields();
        ok($row,"$input serializes valid trait metadata") or next;
        is(scalar(@$row),6,'metadata has exactly six fields');
        is($row->[0],$format{$input},"$input maps to the Field Book format");
        is($row->[4],$categorical ? '0=Низький/1=Високий' : 'Число, межі від нуля','Unicode metadata remain in one details field');
    }
    properties({trait_format=>'Numerical',trait_default_value=>'0',trait_minimum=>'0',trait_maximum=>'100'});
    my $numeric=fields();
    is($numeric->[1],'0','explicit numeric zero default retained');
    is($numeric->[2],'0','explicit zero minimum retained');
    is($numeric->[3],'100','maximum retained');
    properties({trait_format=>'Nominal',trait_default_value=>'0',trait_categories=>'0=Низький/1=Високий'});
    my $categories=fields();
    is($categories->[1],'0','zero-valued category default retained');
    is($categories->[4],'0=Низький/1=Високий','Unicode category descriptions retained');
    is($categories->[5],'0/1','category codes retained');
    my $details="Текст, з \"лапками\"\nта новим рядком";
    properties({trait_format=>'Text',trait_details=>$details});
    my $quoted=fields();
    ok($quoted,'quotes and embedded newline produce valid CSV');
    is($quoted->[4],$details,'quoted details survive the trait metadata serializer') if $quoted;
    1;
};
my $error=$@;
$schema->txn_rollback;
ok($ran,'standard trait properties restored after metadata scenarios') or diag($error);
done_testing;
