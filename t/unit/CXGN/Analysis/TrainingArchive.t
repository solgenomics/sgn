use strict;
use warnings;
use Test::More;
use JSON qw(decode_json);
use File::Temp qw(tempdir);
use File::Slurp qw(write_file);
use CXGN::Analysis::AnalysisCreate;
use CXGN::AnalysisModel::GetModel;
use CXGN::Phenome::Schema;

my ($protocol_row,@archives);
my $temporary=tempdir('sgn-archive-handoff-XXXXXX',TMPDIR=>1,CLEANUP=>1);
write_file("$temporary/training.tsv","trait\n1.5\n");
write_file("$temporary/model.txt","model control\n");
{
    package BoundarySchema; ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
    our @ISA=('Bio::Chado::Schema');
    sub resultset {return bless {},'BoundaryProtocolResultset'}
    sub storage {return bless {},'BoundaryStorage'}
    package BoundaryProtocolResultset;
    sub find {return undef} ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
    sub create {my($self,$row)=@_;$protocol_row=$row;return bless {},'BoundaryProtocolRow'}
    package BoundaryProtocolRow;
    sub nd_protocol_id {return 777}
    package BoundaryStorage;
    sub dbh {return bless {},'BoundaryDbh'}
    package BoundaryDbh;
    sub prepare {return bless {},'BoundaryStatement'}
    package BoundaryStatement;
    sub execute {return 1}
    package BoundaryCv;
    sub cvterm_id {return 777}
}
for my $case ('training_only','model_and_training','returned_error','thrown_error') {
    @archives=();
    my $creator=CXGN::Analysis::AnalysisCreate->new({
        bcs_schema=>bless({},'BoundarySchema'),people_schema=>bless({},'CXGN::People::Schema'),
        metadata_schema=>bless({},'CXGN::Metadata::Schema'),phenome_schema=>bless({},'CXGN::Phenome::Schema'),
        archive_path=>'/tmp/model-boundary-archive',base_path=>'/home/production/cxgn/sgn',
        dbhost=>'unused',dbname=>'unused',dbuser=>'unused',dbpass=>'unused',tempfile_for_deleting_nd_experiment_ids=>'/tmp/not-used',
        analysis_to_save_boolean=>'no',analysis_protocol=>'executed protocol snapshot',analysis_model_properties=>{engine=>'sommer'},
        analysis_model_type=>'mixed_model_lmer',analysis_model_name=>'boundary_'.$case,
        analysis_model_description=>'Synthetic handoff control',analysis_model_language=>'R',analysis_model_is_public=>0,
        analysis_model_application_name=>'Breedbase Mixed Model Tool',analysis_model_application_version=>'0.01',
        analysis_model_file=>($case eq 'model_and_training'?"$temporary/model.txt":undef),analysis_model_file_type=>'mixed_model_object',
        analysis_model_training_data_file=>"$temporary/training.tsv",
        analysis_model_training_data_file_type=>'mixed_model_input_data',
        user_id=>41,user_name=>'janedoe',user_role=>'curator'
    });
    my $result;
    {
        no warnings 'redefine';
        local *SGN::Model::Cvterm::get_cvterm_row=sub{return bless {},'BoundaryCv'};
        local *CXGN::AnalysisModel::GetModel::store_analysis_model_files=sub{my($self,$args)=@_;push @archives,$args;die "archive failure\n" if $case eq 'thrown_error';return {error=>'archive failure'} if $case eq 'returned_error';return undef}; ## no critic (Subroutines::ProhibitExplicitReturnUndef) -- Preserve the explicit absent-value sentinel in every calling context.
        $result=$creator->store();
    }
    ok($result->{success},"actual AnalysisCreate completes $case protocol path");
    if($case =~ /error$/) {
        ok($result->{archive_pending} && @{$result->{warnings}||[]},"$case is explicit partial archive success");
        is($result->{model_id},777,"$case retains the already stored model ID");
    }
    my $stored=decode_json($protocol_row->{nd_protocolprops}[0]{value});
    is($stored->{protocol},'executed protocol snapshot',"actual SaveModel JSON retains $case protocol verbatim");
    ok(@archives==1 && $archives[0]{archived_training_data_file} eq "$temporary/training.tsv","$case calls the standard training-file archiver");
}
done_testing;
