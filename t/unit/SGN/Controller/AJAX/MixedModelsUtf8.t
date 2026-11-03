use strict;
use warnings;
use utf8;
use Test::More;
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use File::Slurp qw(read_file write_file);
use JSON::Any;
use SGN::Controller::AJAX::MixedModels;
use CXGN::MixedModels;
my ($rscript)=grep {-x $_} map {"$_/Rscript"} split /:/,$ENV{PATH};
plan skip_all=>'Rscript unavailable' unless $rscript;
my $base=tempdir('sgn-model-utf8-XXXXXX',TMPDIR=>1,CLEANUP=>1);
{
    package Utf8Person;
    sub get_first_name {return 'Test'}
    sub get_last_name {return 'Operator'}
    package Utf8User;
    sub get_object {return bless {},'Utf8Person'}
    package Utf8Context;
    sub user {return bless {},'Utf8User'}
}
my $controller=SGN::Controller::AJAX::MixedModels->new;
my $context=bless {},'Utf8Context';
for my $case ('ascii','unicode') {
    my $accession=$case eq 'ascii'?'Accession1':'Зразок α';
    my $trait=$case eq 'ascii'?'Height|CO_343:0000001':'Висота|CO_343:0000001';
    my $file="$base/$case.tsv";
    my $source='d<-data.frame(germplasmName="'.$accession.'",value=1.5,check.names=FALSE); names(d)[2]<-"'.$trait.'";write.table(d,"'.$file.'",sep="\t",row.names=FALSE,quote=FALSE)';
    write_file("$base/producer.R",{binmode=>':encoding(UTF-8)'},$source);
    is(system($rscript,"$base/producer.R"),0,"R produced the $case UTF8 TSV");
    my($data,undef,$names,$traits)=$controller->result_file_to_hash($context,$file);
    is_deeply($names,[$accession],"actual result reader retains the $case accession");
    is_deeply($traits,[$trait],"actual result reader retains the $case trait");
    my $transport=JSON::Any->decode(JSON::Any->encode($data));
    ok(exists($transport->{$accession}) && exists($transport->{$accession}{$trait}) && $transport->{$accession}{$trait}[0]==1.5,"$case accession/trait/value survive actual result JSON transport");
}
my @metadata=qw(studyYear programDbId programName programDescription studyDbId studyName studyDescription studyDesign plotWidth plotLength fieldSize fieldTrialIsPlannedToBeGenotyped fieldTrialIsPlannedToCross plantingDate harvestDate locationDbId locationName germplasmDbId germplasmName germplasmSynonyms observationLevel observationUnitDbId observationUnitName replicate blockNumber plotNumber rowNumber colNumber entryType plantNumber plantedSeedlotStockDbId plantedSeedlotStockUniquename plantedSeedlotCurrentCount plantedSeedlotCurrentWeightGram plantedSeedlotBoxName plantedSeedlotTransactionCount plantedSeedlotTransactionWeight plantedSeedlotTransactionDescription availableGermplasmSeedlotUniquenames);
my $trait='Висота|CO_343:0000001';my $file="$base/prepared.tsv";
write_file($file,{binmode=>':encoding(UTF-8)'},join("\t",@metadata,$trait)."\n".join("\t",(1)x39,1.5)."\n");
my $mixed=CXGN::MixedModels->new;$mixed->tempfile($file);$mixed->clean_file($file);
my $conversion=$mixed->read_conversion_matrix($file.'.traits');
my $clean=CXGN::MixedModels::make_R_variable_name($trait);
is($conversion->{$clean},$trait,'actual conversion map uses decoded UTF8 trait keys/values');
$mixed->clean_file($file);$conversion=$mixed->read_conversion_matrix($file.'.traits');
is($conversion->{$clean},$trait,'repeat cleaning retains decoded original UTF8 trait identity');
done_testing;
