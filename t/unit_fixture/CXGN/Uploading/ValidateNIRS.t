
use strict;
use warnings;

use lib 't/lib';
use SGN::Test::Fixture;
use Test::More;
use Test::WWW::Mechanize;
use LWP::UserAgent;
use CXGN::Dataset;
use CXGN::Phenotypes::ParseUpload;
use CXGN::Phenotypes::StorePhenotypes;

#Needed to update IO::Socket::SSL
use Data::Dumper;
use JSON;
local $Data::Dumper::Indent = 0;

my $f = SGN::Test::Fixture->new();

for my $extension ("xls", "xlsx") {

    my $schema = $f->bcs_schema;
    my $dbh = $schema->storage->dbh;
    my $people_schema = $f->people_schema;

    my $mech = Test::WWW::Mechanize->new;

    $mech->post_ok('http://localhost:3010/brapi/v1/token', [ "username" => "janedoe", "password" => "secretpw", "grant_type" => "password" ]);
    my $response = decode_json $mech->content;
    print STDERR Dumper $response;
    is($response->{'metadata'}->{'status'}->[2]->{'message'}, 'Login Successfull');
    my $sgn_session_id = $response->{access_token};
    print STDERR $sgn_session_id . "\n";

    my $location_rs = $schema->resultset('NaturalDiversity::NdGeolocation')->search({ description => 'Cornell Biotech' });
    my $location_id = $location_rs->first->nd_geolocation_id;

    my $bp_rs = $schema->resultset('Project::Project')->search({ name => 'test' });
    my $breeding_program_id = $bp_rs->first->project_id;

    my $tn = CXGN::Trial->new({ bcs_schema => $f->bcs_schema(), trial_id => 137 });
    $tn->create_plant_entities(2);

    my $parser = CXGN::Phenotypes::ParseUpload->new();
    my $filename = "t/data/trial/upload_phenotypin_spreadsheet_large.$extension";
    my $parsed_file = $parser->parse('phenotype spreadsheet', $filename, 0, 'plots', $f->bcs_schema);
    ok($parsed_file, "Check if parse parse phenotype spreadsheet works");

    my %phenotype_metadata;
    $phenotype_metadata{'archived_file'} = $filename;
    $phenotype_metadata{'archived_file_type'} = "spreadsheet phenotype file";
    $phenotype_metadata{'operator'} = "janedoe";
    $phenotype_metadata{'date'} = "2016-02-17_05:15:21";
    my %parsed_data = %{$parsed_file->{'data'}};
    my @plots = @{$parsed_file->{'units'}};
    my @traits = @{$parsed_file->{'variables'}};

    my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new(
        basepath                   => $f->config->{basepath},
        dbhost                     => $f->config->{dbhost},
        dbname                     => $f->config->{dbname},
        dbuser                     => $f->config->{dbuser},
        dbpass                     => $f->config->{dbpass},
        temp_file_nd_experiment_id => $f->config->{cluster_shared_tempdir} . "/test_temp_nd_experiment_id_delete",
        bcs_schema                 => $f->bcs_schema,
        metadata_schema            => $f->metadata_schema,
        phenome_schema             => $f->phenome_schema,
        user_id                    => 41,
        stock_list                 => \@plots,
        trait_list                 => \@traits,
        values_hash                => \%parsed_data,
        has_timestamps             => 0,
        overwrite_values           => 0,
        metadata_hash              => \%phenotype_metadata,
        composable_validation_check_name => $f->config->{composable_validation_check_name}
    );
    my ($verified_warning, $verified_error) = $store_phenotypes->verify();
    ok(!$verified_error);
    my ($stored_phenotype_error_msg, $store_success) = $store_phenotypes->store();
    ok(!$stored_phenotype_error_msg, "check that store large pheno spreadsheet works");

    print STDERR "Uploading NIRS\n";

    my $file = $f->config->{basepath} . "/t/data/NIRS/C16Mval_spectra.csv";

    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_verify',
        Content_Type => 'form-data',
        Content      => [
            upload_nirs_spreadsheet_file_input             => [ $file, 'nirs_data_upload' ],
            "sgn_session_id"                               => $sgn_session_id,
            "upload_nirs_spreadsheet_data_level"           => "plants",
            "upload_nirs_spreadsheet_protocol_name"        => "NIRS SCIO Protocol",
            "upload_nirs_spreadsheet_protocol_desc"        => "description",
            "upload_nirs_spreadsheet_protocol_device_type" => "SCIO"
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    my $message = $response->decoded_content;
    print STDERR Dumper $message;
    my $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{figure});
    is_deeply($message_hash->{success}, [ 'File nirs_data_upload saved in archive.', 'File valid: nirs_data_upload.', 'File data successfully parsed.', 'Aggregated file data successfully parsed.', 'Aggregated file data verified. Plot names and trait names are valid.' ]);

    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/nirs_upload_store',
        Content_Type => 'form-data',
        Content      => [
            upload_nirs_spreadsheet_file_input             => [ $file, 'nirs_data_upload' ],
            "sgn_session_id"                               => $sgn_session_id,
            "upload_nirs_spreadsheet_data_level"           => "plants",
            "upload_nirs_spreadsheet_protocol_name"        => "NIRS SCIO Protocol",
            "upload_nirs_spreadsheet_protocol_desc"        => "description",
            "upload_nirs_spreadsheet_protocol_device_type" => "SCIO"
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{figure});
    is(scalar(@{$message_hash->{success}}), 8);
    is($message_hash->{success}->[6], 'All values in your file have been successfully processed!<br><br>30 new values stored<br>0 previously stored values skipped<br>0 previously stored values overwritten<br>0 previously stored values removed<br><br>');
    my $nirs_protocol_id = $message_hash->{nd_protocol_id};

    my $dry_matter_trait_id = $f->bcs_schema()->resultset("Cv::Cvterm")->find({ name => 'dry matter content percentage' })->cvterm_id();

    my $ds = CXGN::Dataset->new(people_schema => $f->people_schema(), schema => $f->bcs_schema());
    $ds->plots([
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial21' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial22' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial23' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial24' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial25' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial26' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial27' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial28' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial29' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial210' })->stock_id(),
        $f->bcs_schema()->resultset("Stock::Stock")->find({ uniquename => 'test_trial211' })->stock_id()
    ]);
    $ds->traits([
        $dry_matter_trait_id
    ]);
    $ds->name("nirs_dataset_test");
    $ds->description("test nirs description");
    $ds->sp_person_id(41);
    my $sp_dataset_id = $ds->store();

    my $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/Nirs/generate_spectral_plot',
        Content_Type => 'form-data',
        Content      => [
            dataset_id                => $sp_dataset_id,
            "sgn_session_id"          => $sgn_session_id,
            "nd_protocol_id"          => $nirs_protocol_id,
            "query_associated_stocks" => "yes"
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    my $message = $response->decoded_content;
    my $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{figure});

    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/download_file',
        Content_Type => 'form-data',
        Content      => [
            dataset_id                        => $sp_dataset_id,
            nd_protocol_id                    => $nirs_protocol_id,
            "sgn_session_id"                  => $sgn_session_id,
            "high_dimensional_phenotype_type" => "NIRS",
            "query_associated_stocks"         => "yes",
            "download_file_type"              => "data_matrix"
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{download_file_link});

    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/download_file',
        Content_Type => 'form-data',
        Content      => [
            dataset_id                        => $sp_dataset_id,
            nd_protocol_id                    => $nirs_protocol_id,
            "sgn_session_id"                  => $sgn_session_id,
            "high_dimensional_phenotype_type" => "NIRS",
            "query_associated_stocks"         => "yes",
            "download_file_type"              => "identifier_metadata"
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{download_file_link});

    $ua = LWP::UserAgent->new;
    $response = $ua->post(
        'http://localhost:3010/ajax/highdimensionalphenotypes/download_relationship_matrix_file',
        Content_Type => 'form-data',
        Content      => [
            dataset_id                        => $sp_dataset_id,
            nd_protocol_id                    => $nirs_protocol_id,
            "sgn_session_id"                  => $sgn_session_id,
            "high_dimensional_phenotype_type" => "NIRS",
            "query_associated_stocks"         => "yes",
        ]
    );

    #print STDERR Dumper $response;
    ok($response->is_success);
    $message = $response->decoded_content;
    $message_hash = decode_json $message;
    print STDERR Dumper $message_hash;
    ok($message_hash->{download_file_link});

    # $ua = LWP::UserAgent->new;
    # $response = $ua->post(
    #         'http://localhost:3010/ajax/Nirs/generate_results',
    #         Content_Type => 'form-data',
    #         Content => [
    #             train_dataset_id => $sp_dataset_id,
    #             trait_id => $dry_matter_trait_id,
    #             "format"=>"SCIO",
    #             "cv"=>"random",
    #             "algorithm"=>"pls",
    #             "niter"=>10,
    #             "tune"=>10,
    #             "preprocessing"=>"1",
    #             "rf"=>0,
    #             "sgn_session_id"=>$sgn_session_id
    #         ]
    #     );
    #
    # print STDERR Dumper $response;
    # ok($response->is_success);
    # $message = $response->decoded_content;
    # $message_hash = decode_json $message;
    # print STDERR Dumper $message_hash;
    # ok($message_hash->{model_properties});
    # ok($message_hash->{model_file});
    # ok($message_hash->{training_data_file});
    # ok($message_hash->{performance_output});
    $f->clean_up_db();
}

done_testing();
