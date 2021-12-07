=head1 NAME

SGN::Controller::AJAX::BreedersToolbox::ProductProfile
REST controller for storing and viewing product profiles and associated data

=head1 DESCRIPTION


=head1 AUTHOR

Titima Tantikanjana <tt15@cornell.edu>

=cut

package SGN::Controller::AJAX::BreedersToolbox::ProductProfile;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

use List::MoreUtils qw | any all |;
use JSON::Any;
use Data::Dumper;
use Try::Tiny;
use Math::Round;
use CXGN::BreedingProgram;
use CXGN::Phenotypes::PhenotypeMatrix;
use CXGN::BreedersToolbox::Projects;
use CXGN::Stock::Search;
use JSON;
use CXGN::BreedersToolbox::ProductProfile;
use CXGN::BreedersToolbox::ProductProfileprop;
use File::Spec::Functions;
use Spreadsheet::WriteExcel;

use File::Basename qw | basename dirname|;
use File::Copy;
use Digest::MD5;
use DateTime;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
    );


sub create_profile_template : Path('/ajax/product_profile/create_profile_template') : ActionClass('REST') { }

sub create_profile_template_POST : Args(0) {
    my ($self, $c) = @_;

    if (!$c->user()) {
        $c->stash->{rest} = {error => "You need to be logged in to create a product profile template" };
        return;
    }
    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
        $c->stash->{rest} = {error =>  "You have insufficient privileges to create a product profile template." };
        return;
    }
    my $metadata_schema = $c->dbic_schema('CXGN::Metadata::Schema');

    my $template_file_name = $c->req->param('template_file_name');
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory_name = "profile_template_files";
    my $archived_file_name = catfile($user_id, $subdirectory_name,$timestamp."_".$template_file_name.".xls");
    my $archive_path = $c->config->{archive_path};
    my $file_destination =  catfile($archive_path, $archived_file_name);
    my $dbh = $c->dbc->dbh();
    my @trait_ids;
    my @trait_list = @{_parse_list_from_json($c->req->param('trait_list_json'))};
#    print STDERR "TRAIT LIST =".Dumper(\@trait_list)."\n";

    my %errors;
    my @error_messages;
    my $tempfile = $c->config->{basepath}."/".$c->tempfile( TEMPLATE => 'other/excelXXXX');
    my $wb = Spreadsheet::WriteExcel->new($tempfile);
    if (!$wb) {
        push @error_messages, "Could not create file.";
        $errors{'error_messages'} = \@error_messages;
        return \%errors;
    }

    my $ws = $wb->add_worksheet();

    my @headers = ('Trait Name','Target Value','Benchmark Variety','Performance (equal, smaller, larger)','Weight','Trait Type');

    for(my $n=0; $n<scalar(@headers); $n++) {
        $ws->write(0, $n, $headers[$n]);
    }

    my $line = 1;
    foreach my $trait (@trait_list) {
        $ws->write($line, 0, $trait);
        $line++;
    }

    $wb->close();

    open(my $F, "<", $tempfile) || die "Can't open file ".$self->tempfile();
    binmode $F;
    my $md5 = Digest::MD5->new();
    $md5->addfile($F);
    close($F);

    if (!-d $archive_path) {
        mkdir $archive_path;
    }

    if (! -d catfile($archive_path, $user_id)) {
        mkdir (catfile($archive_path, $user_id));
    }

    if (! -d catfile($archive_path, $user_id,$subdirectory_name)) {
        mkdir (catfile($archive_path, $user_id, $subdirectory_name));
    }

    my $md_row = $metadata_schema->resultset("MdMetadata")->create({
        create_person_id => $user_id,
    });
    $md_row->insert();

    my $file_row = $metadata_schema->resultset("MdFiles")->create({
        basename => basename($file_destination),
        dirname => dirname($file_destination),
        filetype => 'profile template xls',
        md5checksum => $md5->hexdigest(),
        metadata_id => $md_row->metadata_id(),
    });
    $file_row->insert();
    my $file_id = $file_row->file_id();

    move($tempfile,$file_destination);
    unlink $tempfile;

    my $result = $file_row->file_id;

#    print STDERR "FILE =".Dumper($file_destination)."\n";
#    print STDERR "FILE ID =".Dumper($file_id)."\n";

    $c->stash->{rest} = {
        success => 1,
        result => $result,
        file => $file_destination,
        file_id => $file_id,
    };

}


sub upload_profile : Path('/ajax/product_profile/upload_profile') : ActionClass('REST') { }
sub upload_profile_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh();

    if ($session_id){
        my @user_info = CXGN::Login->new($dbh)->query_from_cookie($session_id);
        if (!$user_info[0]){
            $c->stash->{rest} = {error=>'You must be logged in to upload product profile!'};
            return;
        }
        $user_id = $user_info[0];
        $user_role = $user_info[1];
        my $p = CXGN::People::Person->new($dbh, $user_id);
        $user_name = $p->get_username;
    } else{
        if (!$c->user){
            $c->stash->{rest} = {error=>'You must be logged in to upload product profile!'};
            return;
        }
        $user_id = $c->user()->get_object()->get_sp_person_id();
        $user_name = $c->user()->get_object()->get_username();
        $user_role = $c->user->get_object->get_user_type();
    }

    if (!any { $_ eq 'curator' || $_ eq 'submitter' } ($user_role)) {
        $c->stash->{rest} = {error =>  'You have insufficient privileges to upload product profile.' };
        return;
    }

    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
#    my $program_id = $c->req->param('profile_program_id');
    my $new_profile_name = $c->req->param('new_profile_name');
    my $new_profile_scope = $c->req->param('new_profile_scope');
    $new_profile_name =~ s/^\s+|\s+$//g;

#    my $profile_obj = CXGN::BreedersToolbox::ProductProfile->new({ bcs_schema => $schema, parent_id => $program_id });
#    my $profiles = $profile_obj->get_product_profile_info();
#    my @db_profile_names;
#    foreach my $profile(@$profiles){
#        my @profile_info = @$profile;
#        my $stored_profile_name = $profile_info[1];
#        push @db_profile_names, $stored_profile_name;
#    }
#    if ($new_profile_name ~~ @db_profile_names){
#        $c->stash->{rest} = {error=>'Please use different product profile name. This name is already used for another product profile!'};
#        return;
#    }

    my $upload = $c->req->upload('profile_uploaded_file');
    my $subdirectory = "profile_upload";
    my $upload_original_name = $upload->filename();
    my $upload_tempfile = $upload->tempname;
    my $time = DateTime->now();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $uploaded_date = $time->ymd();
#    print STDERR "PROGRAM ID =".Dumper($program_id)."\n";
#    print STDERR "PROFILE NAME =".Dumper($new_profile_name)."\n";
#    print STDERR "PROFILE SCOPE =".Dumper($new_profile_scope)."\n";

    ## Store uploaded temporary file in archive
    my $uploader = CXGN::UploadFile->new({
        tempfile => $upload_tempfile,
        subdirectory => $subdirectory,
        archive_path => $c->config->{archive_path},
        archive_filename => $upload_original_name,
        timestamp => $timestamp,
        user_id => $user_id,
        user_role => $user_role
    });
    my $archived_filename_with_path = $uploader->archive();
    my $md5 = $uploader->get_md5($archived_filename_with_path);
    if (!$archived_filename_with_path) {
        $c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
        $c->detach();
    }
    unlink $upload_tempfile;
    my $parser = CXGN::Trial::ParseUpload->new(chado_schema => $schema, filename => $archived_filename_with_path);
    $parser->load_plugin('ProfileXLS');
    my $parsed_data = $parser->parse();
    print STDERR "PARSED DATA =".Dumper($parsed_data)."\n";

    my $profile_detail_string;
    if ($parsed_data){
        $profile_detail_string = encode_json $parsed_data;
    }

    if (!$parsed_data) {
        my $return_error = '';
        my $parse_errors;
        if (!$parser->has_parse_errors() ){
            $c->stash->{rest} = {error_string => "Could not get parsing errors"};
        } else {
            $parse_errors = $parser->get_parse_errors();
            #print STDERR Dumper $parse_errors;

            foreach my $error_string (@{$parse_errors->{'error_messages'}}){
                $return_error .= $error_string."<br>";
            }
        }
        $c->stash->{rest} = {error_string => $return_error, missing_accessions => $parse_errors->{'missing_accessions'} };
        $c->detach();
    }

    my $profile = CXGN::BreedersToolbox::ProductProfile->new({ people_schema => $people_schema, dbh => $dbh });
    #need to add sp stage gate
    $profile->sp_stage_gate_id('1');
    $profile->name($new_profile_name);
    $profile->scope($new_profile_scope);
    $profile->sp_person_id($user_id);
    $profile->create_date($uploaded_date);
    my $product_profile_id = $profile->store();
    #print STDERR "PRODUCT PROFILE ID =".($product_profile_id)."\n";
    if (!$product_profile_id){
        $c->stash->{rest} = {error_string => "Error saving your product profile",};
        return;
    }

    my $history_info ->{'create'} = $uploaded_date;
    push my @history, $history_info;

    my $product_profileprop = CXGN::BreedersToolbox::ProductProfileprop->new({ bcs_schema => $schema, people_schema => $people_schema});
    $product_profileprop->product_profile_details($profile_detail_string);
    $product_profileprop->parent_id($product_profile_id);
    $product_profileprop->history(\@history);
    my $product_profileprop_id = $product_profileprop->store_people_schema_prop();
    print STDERR "PRODUCT PROFILE PROP ID =".($product_profileprop_id)."\n";

    if (!$product_profileprop_id){
        $c->stash->{rest} = {error_string => "Error saving your product profile",};
        return;
    }

#    my $project_prop_id = $profile->store_by_rank();

#    if ($@) {
#        $c->stash->{rest} = { error => $@ };
#        print STDERR "An error condition occurred, was not able to upload profile. ($@).\n";
#        $c->detach();
#    }


    $c->stash->{rest} = { success => 1 };

}


sub add_product_profile : Path('/ajax/product_profile/add_product_profile') : ActionClass('REST') { }

sub add_product_profile_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $program_id = $c->req->param('profile_program_id');
    my $product_profile_name = $c->req->param('product_profile_name');
    my $product_profile_scope = $c->req->param('product_profile_scope');
    my $trait_list_json = $c->req->param('trait_list_json');
    my $target_values_json = $c->req->param('target_values_json');

    my @traits = @{_parse_list_from_json($trait_list_json)};
    my @target_values = @{_parse_list_from_json($target_values_json)};

    my %trait_value_hash;
    for my $i (0 .. $#traits) {
        $trait_value_hash{$traits[$i]} = $target_values[$i];
    }
    my $profile_string = encode_json \%trait_value_hash;

    my $product_profile = CXGN::BreedersToolbox::ProductProfile->new({ bcs_schema => $schema });
    $product_profile->product_profile_name($product_profile_name);
    $product_profile->product_profile_scope($product_profile_scope);
    $product_profile->product_profile_details($profile_string);
    $product_profile->parent_id($program_id);
	my $project_prop_id = $product_profile->store_by_rank();

#    print STDERR "PROJECT PROP ID =".Dumper($project_prop_id)."\n";
    if ($@) {
        $c->stash->{rest} = { error => "Error storing product profile. ($@)" };
        return;
    }

    $c->stash->{rest} = { success => 1};
}


sub get_product_profiles :Path('/ajax/product_profile/get_product_profiles') Args(0){

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my $people_schema = $c->dbic_schema('CXGN::People::Schema');
    my $dbh = $c->dbc->dbh;

#    my $program = $c->stash->{program};
#    my $program_id = $program->get_program_id;
#    my $schema = $c->stash->{schema};

    my $profile_obj = CXGN::BreedersToolbox::ProductProfile->new({ dbh => $dbh, people_schema => $people_schema });
    my $profiles = $profile_obj->get_product_profile_info();
    print STDERR "PRODUCT PROFILE RESULTS =".Dumper($profiles)."\n";
    my @profile_summary;
    foreach my $profile(@$profiles){
        my @trait_list = ();
        my @profile_info = @$profile;
        my $profile_id = $profile_info[0];
        my $profile_name = $profile_info[1];
        my $profile_name_link = qq{<a href = "/breeders/product_profile_details/$profile_id">$profile_name</a>};
        my $profile_scope = $profile_info[2];
        my $profile_details = $profile_info[3];
        my $profile_submitter = $profile_info[4];
        my $create_date = $profile_info[5];
        my $modified_date = $profile_info[6];
        print STDERR "PRODUCT PROFILE DETAILS =".Dumper($profile_details)."\n";
        my $trait_string;
        if ($profile_details) {
            my $trait_info_ref = decode_json $profile_details;
            my %trait_info_hash = %{$trait_info_ref};
            my @traits = keys %trait_info_hash;
            foreach my $trait(@traits){
                my @trait_name = ();
                @trait_name = split '\|', $trait;
                pop @trait_name;
                push @trait_list, @trait_name
            }
            my @sort_trait_list = sort @trait_list;
            $trait_string = join("<br>", @sort_trait_list);
        }
        push @profile_summary, [$profile_name_link, $profile_scope, $trait_string, $profile_submitter, $create_date, $modified_date] ;
    }
#    print STDERR "TRAIT LIST =".Dumper(\@profile_summary)."\n";

    $c->stash->{rest} = {data => \@profile_summary};

}


sub get_profile_details :Path('/ajax/product_profile/get_profile_details') :Args(1) {
    my $self = shift;
    my $c = shift;
    my $profile_id = shift;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $profile_json_type_id = SGN::Model::Cvterm->get_cvterm_row($c->dbic_schema("Bio::Chado::Schema"), 'product_profile_json', 'project_property')->cvterm_id();
    my $profile_rs = $schema->resultset("Project::Projectprop")->search({ projectprop_id => $profile_id, type_id => $profile_json_type_id });

    my $profile_row = $profile_rs->next();
    my $profile_detail_string = $profile_row->value();

    my $profile_detail_hash = decode_json $profile_detail_string;
    my $trait_info_string = $profile_detail_hash->{'product_profile_details'};

    my $trait_info_hash_ref = decode_json $trait_info_string;
    my @all_details;
    my %trait_info_hash = %{$trait_info_hash_ref};
    my @traits = keys %trait_info_hash;

    foreach my $trait_name(@traits){
        my @trait_row = ();
        push @trait_row, $trait_name;

        my $target_value = $trait_info_hash{$trait_name}{'target_value'};
        if (defined $target_value){
            push @trait_row, $target_value;
        } else {
            push @trait_row, 'N/A';
        }

        my $benchmark_variety = $trait_info_hash{$trait_name}{'benchmark_variety'};
        if (defined $benchmark_variety){
            push @trait_row, $benchmark_variety;
        } else {
            push @trait_row, 'N/A';
        }

        my $performance = $trait_info_hash{$trait_name}{'performance'};
        if (defined $performance){
            push @trait_row, $performance;
        } else {
            push @trait_row, 'N/A';
        }

        my $weight = $trait_info_hash{$trait_name}{'weight'};
        if (defined $weight) {
            push @trait_row, $weight;
        } else {
            push @trait_row, 'N/A';
        }

        my $trait_type = $trait_info_hash{$trait_name}{'trait_type'};
        if (defined $trait_type) {
            push @trait_row, $trait_type;
        } else {
            push @trait_row, 'N/A';
        }

        push @all_details, [@trait_row];
    }
#    print STDERR "ALL DETAILS =".Dumper(\@all_details)."\n";
    $c->stash->{rest} = {data => \@all_details};

}


sub _parse_list_from_json {
    my $list_json = shift;
    my $json = new JSON;
    if ($list_json) {
        my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
        #my $decoded_list = decode_json($list_json);
        my @array_of_list_items = @{$decoded_list};
        return \@array_of_list_items;
    }
    else {
        return;
    }
}


1;
