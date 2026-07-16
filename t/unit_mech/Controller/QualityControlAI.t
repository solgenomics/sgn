#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use lib 't/lib';
use CXGN::AI::Client;
use SGN::Controller::AJAX::AI;
use SGN::Test::WWW::Mechanize skip_cgi => 1;

my $development_client = CXGN::AI::Client->new(
    service_url => 'http://breedbase-ai.invalid',
    delegation_token => undef,
    development_user_context => {
        user_id => 263,
        username => 'curator',
        roles => ['curator'],
        scopes => ['dataset:read', 'phenotype:read'],
    },
);
my %development_headers = $development_client->_headers;
is($development_headers{'X-Breedbase-User-Id'}, 263, 'undefined delegation token uses the development user context');
ok(!exists $development_headers{'X-Breedbase-AI-Delegation'}, 'undefined delegation token is not sent');

my $ai_gateway = SGN::Controller::AJAX::AI->new;
is(
    $ai_gateway->_extract_dataset_name("filter dataset outliers_test_dataset for all traits"),
    "outliers_test_dataset",
    "AI gateway extracts an unquoted dataset name from the reported command",
);
is(
    $ai_gateway->_extract_dataset_name(q{filter dataset "Outliers test dataset" for all traits}),
    "Outliers test dataset",
    "AI gateway extracts a quoted dataset name containing spaces",
);
is(
    $ai_gateway->_dataset_id_for_name([[225, "outliers_test_dataset", "test"]], "outliers_test_dataset"),
    225,
    "AI gateway resolves one exact dataset name to its numeric ID",
);
is(
    $ai_gateway->_dataset_id_for_name([[225, "public - outliers_test_dataset", "test"]], "outliers_test_dataset"),
    225,
    "AI gateway resolves the display prefix used for public datasets",
);
ok(
    !defined $ai_gateway->_dataset_id_for_name(
        [[225, "duplicate", "one"], [226, "duplicate", "two"]],
        "duplicate",
    ),
    "AI gateway does not guess when a dataset name is ambiguous",
);

my $controller = do {
    open my $fh, '<', 'lib/SGN/Controller/QualityControl.pm' or die "Cannot open QualityControl controller: $!";
    local $/;
    <$fh>;
};
like($controller, qr/sub\s+quality_control_index\s+:Path\('\/tools\/qualitycontrol'\)/, '/tools/qualitycontrol route exists');
like($controller, qr/stash->\{template\}\s*=\s*'\/tools\/qualityControl\/dataset_quality_control\.mas'/, '/tools/qualitycontrol renders dataset_quality_control.mas');

my $validated_controller = do {
    open my $fh, '<', 'lib/SGN/Controller/ValidatedTrials.pm' or die "Cannot open ValidatedTrials controller: $!";
    local $/;
    <$fh>;
};
like($validated_controller, qr/sub\s+quality_control_index\s+:Path\('\/tools\/validatedtrials'\)/, '/tools/validatedtrials route exists');
like($validated_controller, qr/stash->\{template\}\s*=\s*'\/tools\/qualityControl\/validated_trials\.mas'/, '/tools/validatedtrials renders validated_trials.mas');

my $mech = SGN::Test::WWW::Mechanize->new;
my $config = $mech->context->config;

{
    local $config->{enable_ai_agent} = 0;
    $mech->get_ok('/bare_mason/tools/qualityControl/dataset_quality_control', 'Quality Control Mason page renders when AI is disabled');
    $mech->content_lacks('id="analyze_with_breedbase_ai_button"', 'dataset QC AI button is not rendered when AI is disabled');
    $mech->get_ok('/bare_mason/tools/qualityControl/validated_trials', 'Validated Trials Mason page renders when AI is disabled');
    $mech->content_lacks('id="analyze_with_breedbase_ai_button"', 'validated trials AI button is not rendered when AI is disabled');
}

{
    local $config->{enable_ai_agent} = 1;
    $mech->get_ok('/bare_mason/tools/qualityControl/dataset_quality_control', 'Quality Control Mason page renders when AI is enabled');
    $mech->content_contains('id="breedbase_ai_qc_container"', 'dataset QC AI container is rendered when AI is enabled');
    $mech->content_contains('id="analyze_with_breedbase_ai_button"', 'dataset QC command button is rendered when AI is enabled');
    $mech->content_unlike(qr/<button[^>]+id="analyze_with_breedbase_ai_button"[^>]+disabled/, 'dataset QC command button is available before QC analysis');
    $mech->content_contains('id="breedbase_ai_command_input"', 'dataset QC command textarea is rendered');
    $mech->content_contains('id="breedbase_ai_command_plan"', 'dataset QC plan preview is rendered');
    $mech->content_contains('id="breedbase_ai_command_pending"', 'dataset QC pending action area is rendered');

    my $content = $mech->content;
    ok(index($content, 'id="analyze_with_breedbase_ai_button"') < index($content, 'Choose the dataset for QC'), 'dataset QC AI control is rendered before the workflow steps');

    $mech->get_ok('/bare_mason/tools/qualityControl/validated_trials', 'Validated Trials Mason page renders when AI is enabled');
    $mech->content_contains('id="breedbase_ai_qc_container"', 'validated trials AI container is rendered when AI is enabled');
    $mech->content_contains('id="analyze_with_breedbase_ai_button"', 'validated trials command button is rendered when AI is enabled');
    $mech->content_unlike(qr/<button[^>]+id="analyze_with_breedbase_ai_button"[^>]+disabled/, 'validated trials command button is available before statistics are calculated');
    $mech->content_contains('Use QC for filtering traits from dataset 225', 'validated trials command example is rendered');

    my $validated_content = $mech->content;
    ok(index($validated_content, 'id="analyze_with_breedbase_ai_button"') < index($validated_content, 'id="calculate_statistics"'), 'validated trials AI control is rendered before Calculate Statistics');
}

my $js = do {
    open my $fh, '<', 'js/source/entries/qualitycontrol.js' or die "Cannot open qualitycontrol.js: $!";
    local $/;
    <$fh>;
};
like($js, qr/updateBreedbaseAIContext\(result, r\.data, trait_selected, outlierMultiplier\)/, 'trait change updates AI context from QC result');
like($js, qr/window\.BreedbaseAICommandContext\s*=\s*breedbaseAILastContext/, 'dataset QC publishes structured context to the command dialog');

my $mason = do {
    open my $fh, '<', 'mason/tools/qualityControl/dataset_quality_control.mas' or die "Cannot open dataset_quality_control.mas: $!";
    local $/;
    <$fh>;
};
ok(index($mason, '<& /ai/command_panel.mas') < index($mason, '<&| /util/workflow.mas'), 'dataset QC command dialog is included before the workflow steps');

my $validated_mason = do {
    open my $fh, '<', 'mason/tools/qualityControl/validated_trials.mas' or die "Cannot open validated_trials.mas: $!";
    local $/;
    <$fh>;
};
ok(index($validated_mason, '<& /ai/command_panel.mas') < index($validated_mason, 'id="calculate_statistics"'), 'validated trials command dialog is above Calculate Statistics');
like($validated_mason, qr/updateBreedbaseAIContextFromValidatedTrials\(response, stats\)/, 'validated trials statistics success updates AI context');

my $command_panel = do {
    open my $fh, '<', 'mason/ai/command_panel.mas' or die "Cannot open command_panel.mas: $!";
    local $/;
    <$fh>;
};
like($command_panel, qr/url:\s*'\/ajax\/ai\/command'/, 'command dialog calls the same-origin SGN gateway');
like($command_panel, qr/\.text\(response\.message \|\| ''\)/, 'AI response message is rendered as text');
unlike($command_panel, qr/\.html\(response\.message/, 'AI response is not inserted as arbitrary HTML');
like($command_panel, qr/action\.action_type === 'confirm_workflow'/, 'command dialog renders controlled plan confirmation');
like($command_panel, qr/action\.action_type === 'approve_pending_action'/, 'command dialog renders controlled pending action approval');

my $ai_controller = do {
    open my $fh, '<', 'lib/SGN/Controller/AJAX/AI.pm' or die "Cannot open AI gateway controller: $!";
    local $/;
    <$fh>;
};
like($ai_controller, qr/sub\s+command\s+:\s*Path\('\/ajax\/ai\/command'\)/, 'SGN exposes the authenticated AI command gateway');
like($ai_controller, qr/Unsupported AI command action/, 'SGN rejects unregistered browser command actions');
like($ai_controller, qr/sub\s+_is_boolean/, 'SGN validates scalar and JSON boolean workflow confirmation values');

my $ai_client = do {
    open my $fh, '<', 'lib/CXGN/AI/Client.pm' or die "Cannot open AI service client: $!";
    local $/;
    <$fh>;
};
like($ai_client, qr/'\/api\/v1\/agent\/command'/, 'SGN client calls the FastAPI command endpoint');

my $dataset_controller = do {
    open my $fh, '<', 'lib/SGN/Controller/AJAX/Dataset.pm' or die "Cannot open Dataset controller: $!";
    local $/;
    <$fh>;
};
like($dataset_controller, qr/exclude_phenotype_outlier\s*=>\s*\$exclude_phenotype_outlier/, 'dataset phenotype reads propagate database-outlier exclusion');

done_testing();
