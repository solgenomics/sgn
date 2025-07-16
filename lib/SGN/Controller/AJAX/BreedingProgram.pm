
=head1 NAME

SGN::Controller::AJAX::BreedingProgram
 REST controller for viewing breeding programs and the data associated with them

=head1 DESCRIPTION


=head1 AUTHOR

Naama Menda <nm249@cornell.edu>
Titima Tantikanjana <tt15@cornell.edu>

=cut

package SGN::Controller::AJAX::BreedingProgram;

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
use File::Spec::Functions;
use Spreadsheet::WriteExcel;
use CXGN::People::Person;

use File::Basename qw | basename dirname|;
use File::Copy;
use Digest::MD5;
use DateTime;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON'  },
    );


=head2 action program_trials()

  Usage:        /breeders/program/<program_id>/datatables/trials
  Desc:         retrieves trials associated with the breeding program
  Ret:          a table in json suitable for datatables
  Args:
    Side Effects:
  Example:

=cut


sub ajax_breeding_program : Chained('/')  PathPart('ajax/breeders/program')  CaptureArgs(1) {
    my ($self, $c, $program_id) = @_;

    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
    my $program = CXGN::BreedingProgram->new( { schema=> $schema , program_id => $program_id } );

    $c->stash->{schema} = $schema;
    $c->stash->{program} = $program;

}


sub program_trials :Chained('ajax_breeding_program') PathPart('trials') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};

    my $trials = $program->get_trials();

    my @formatted_trials;
    while (my $trial = $trials->next ) {

	my $name = $trial->name;
	my $id = $trial->project_id;
	my $description = $trial->description;
        push @formatted_trials, [ '<a href="/breeders/trial/'.$id.'">'.$name.'</a>', $description ];
    }
    $c->stash->{rest} = { data => \@formatted_trials };
}


sub phenotype_summary : Chained('ajax_breeding_program') PathPart('phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};
    my $round = Math::Round::Var->new(0.01);
    my $dbh = $c->dbc->dbh();

    my $trials = $program->get_trials;
    my @trial_ids;
    while (my $trial = $trials->next() ) {
	my $trial_id = $trial->project_id;
	push @trial_ids , $trial_id;
    }
    my $trial_ids = join ',', map { "?" } @trial_ids;
    my @phenotype_data;
    my @trait_list;

    if ( $trial_ids ) {
	my $h = $dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait,
        cvterm.cvterm_id,
        count(phenotype.value),
        to_char(avg(phenotype.value::real), 'FM999990.990'),
        to_char(max(phenotype.value::real), 'FM999990.990'),
        to_char(min(phenotype.value::real), 'FM999990.990'),
        to_char(stddev(phenotype.value::real), 'FM999990.990')

        FROM cvterm
            JOIN phenotype ON (cvterm_id=cvalue_id)
            JOIN nd_experiment_phenotype USING(phenotype_id)
            JOIN nd_experiment_project USING(nd_experiment_id)
            JOIN nd_experiment_stock USING(nd_experiment_id)
            JOIN stock as plot USING(stock_id)
            JOIN stock_relationship on (plot.stock_id = stock_relationship.subject_id)
            JOIN stock as accession on (accession.stock_id = stock_relationship.object_id)
            JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id
        WHERE project_id IN ( $trial_ids )
            AND phenotype.value~?

        GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id
        ORDER BY cvterm.name ASC
       ;");

	my $numeric_regex = '^-?[0-9]+([,.][0-9]+)?$';
	$h->execute( @trial_ids , $numeric_regex);

        while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev) = $h->fetchrow_array()) {
	    push @trait_list, [$trait_id, $trait];
	    my $cv = 0;
	    if ($stddev && $average != 0) {
		$cv = ($stddev /  $average) * 100;
		$cv = $round->round($cv) . '%';
	    }
	    if ($average) { $average = $round->round($average); }
	    if ($min) { $min = $round->round($min); }
	    if ($max) { $max = $round->round($max); }
	    if ($stddev) { $stddev = $round->round($stddev); }

	    my @return_array;


	    push @return_array, ( qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $cv, $count, qq{<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change($program_id, $trait_id)"><span class="glyphicon glyphicon-stats"></span></a>} );
	    push @phenotype_data, \@return_array;
	}
    }
    $c->stash->{trait_list} = \@trait_list;
    $c->stash->{rest} = { data => \@phenotype_data };
}


sub traits_assayed : Chained('ajax_breeding_program') PathPart('traits_assayed') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my @traits_assayed  =  $program->get_traits_assayed;
    $c->stash->{rest} = { traits_assayed => \@traits_assayed };
}

sub trait_phenotypes : Chained('ajax_breeding_program') PathPart('trait_phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    #get userinfo from db
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    #my $user = $c->user();
    #if (! $c->user) {
    #  $c->stash->{rest} = {
    #    status => "not logged in"
    #  };
    #  return;
    #}
    my $display = $c->req->param('display') || 'plot' ;
    my $trials = $program->get_trials;
    my @trial_ids;
    while (my $trial = $trials->next() ) {
	my $trial_id = $trial->project_id;
	push @trial_ids , $trial_id;
    }
    my $trait = $c->req->param('trait');
    my $phenotypes_search = CXGN::Phenotypes::PhenotypeMatrix->new(
        bcs_schema=> $schema,
        search_type => "MaterializedViewTable",
        data_level => $display,
        trait_list=> [$trait],
        trial_list => \@trial_ids
    );
    my @data = $phenotypes_search->get_phenotype_matrix();
    $c->stash->{rest} = {
      status => "success",
      data => \@data
   };
}


sub accessions : Chained('ajax_breeding_program') PathPart('accessions') Args(0) {
    my ($self, $c) = @_;
    my $program = $c->stash->{program};
    my $accessions = $program->get_accessions;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
    my @formatted_accessions;


    foreach my $id ( @$accessions ) {
	my $acc =  my $row = $schema->resultset("Stock::Stock")->find(
	    { stock_id => $id , }
	    );

	my $name        = $acc->uniquename;
	my $description = $acc->description;
	push @formatted_accessions, [ '<a href="/stock/' .$id. '/view">'.$name.'</a>', $description ];
    }
    $c->stash->{rest} = { data => \@formatted_accessions };
}


sub program_locations :Chained('ajax_breeding_program') PathPart('locations') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_locations = $program->get_locations_with_details();
    $c->stash->{rest} = {data => $program_locations};

}


sub program_field_trials :Chained('ajax_breeding_program') PathPart('field_trials') Args(0){
    my $self = shift;
    my $c = shift;

    my $start_date = $c->req->param("start_date");
    my $end_date = $c->req->param("end_date");
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};

    my $projects = CXGN::BreedersToolbox::Projects->new({schema => $schema});
    my @all_trials = $projects->get_trials_by_breeding_program($program_id, $start_date, $end_date);
    my $field_trials_ref = $all_trials[0];

    my @field_trials;
    my @field_trial_data;

    if (defined $field_trials_ref) {
        @field_trials = @$field_trials_ref;
    }

    foreach my $trial(@field_trials){
        push @field_trial_data, ['<a href="/breeders/trial/'.$$trial[0].'">'.$$trial[1].'</a>', $$trial[2]];
    }

    $c->stash->{rest} = {data => \@field_trial_data};

}


sub program_genotyping_plates :Chained('ajax_breeding_program') PathPart('genotyping_plates') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};

    my $projects = CXGN::BreedersToolbox::Projects->new({schema => $schema});
    my @all_trials = $projects->get_trials_by_breeding_program($program_id);
    my $genotyping_plates_ref = $all_trials[2];

    my @genotyping_plates;
    my @genotyping_plate_data;

    if (defined $genotyping_plates_ref) {
        @genotyping_plates = @$genotyping_plates_ref;
    }

    foreach my $plate(@genotyping_plates){
        push @genotyping_plate_data, ['<a href="/breeders/trial/'.$$plate[0].'">'.$$plate[1].'</a>', $$plate[2]];
    }

    $c->stash->{rest} = {data => \@genotyping_plate_data};

}


sub program_crossing_experiments :Chained('ajax_breeding_program') PathPart('crossing_experiments') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};

    my $projects = CXGN::BreedersToolbox::Projects->new({schema => $schema});
    my @all_trials = $projects->get_trials_by_breeding_program($program_id);
    my $crossing_experiment_ref = $all_trials[1];

    my @crossing_experiments;
    my @crossing_experiment_data;

    if (defined $crossing_experiment_ref) {
        @crossing_experiments = @$crossing_experiment_ref;
    }

    foreach my $experiment(@crossing_experiments){
        push @crossing_experiment_data, ['<a href="/breeders/trial/'.$$experiment[0].'">'.$$experiment[1].'</a>', $$experiment[2]];
    }

    $c->stash->{rest} = {data => \@crossing_experiment_data};

}


sub program_crosses :Chained('ajax_breeding_program') PathPart('crosses') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $result = $program->get_crosses;

    my @cross_data;
    foreach my $r (@$result){
        my ($cross_id, $cross_name, $female_parent_id, $female_parent_name, $male_parent_id, $male_parent_name, $cross_type) = @$r;
        push @cross_data, [qq{<a href="/cross/$cross_id">$cross_name</a>},
        qq{<a href="/stock/$female_parent_id/view">$female_parent_name</a>},
        qq{<a href="/stock/$male_parent_id/view">$male_parent_name</a>}, $cross_type]
    }

    $c->stash->{rest} = {data => \@cross_data};

}


sub program_seedlots :Chained('ajax_breeding_program') PathPart('seedlots') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $result = $program->get_seedlots;
#    print STDERR "SEEDLOTS =".Dumper($result)."\n";
    my @seedlot_data;
    foreach my $r (@$result){
        my ($seedlot_id, $seedlot_name, $content_id, $content_name, $content_type) = @$r;
        if ($content_type eq 'accession') {
            push @seedlot_data, [qq{<a href="/breeders/seedlot/$seedlot_id">$seedlot_name</a>},
            qq{<a href="/stock/$content_id/view">$content_name</a>}, $content_type]
        } elsif ($content_type eq 'cross') {
            push @seedlot_data, [qq{<a href="/breeders/seedlot/$seedlot_id">$seedlot_name</a>},
            qq{<a href="/cross/$content_id">$content_name</a>}, $content_type]
        }
    }

    $c->stash->{rest} = {data => \@seedlot_data};

}


sub add_product_profile : Path('/ajax/breeders/program/add_product_profile') : ActionClass('REST') { }

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


sub get_product_profiles :Chained('ajax_breeding_program') PathPart('product_profiles') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};

    my $profile_obj = CXGN::BreedersToolbox::ProductProfile->new({ bcs_schema => $schema, parent_id => $program_id });
    my $profiles = $profile_obj->get_product_profile_info();
#    print STDERR "PRODUCT PROFILE RESULTS =".Dumper($profiles)."\n";
    my @profile_summary;
    foreach my $profile(@$profiles){
        my @trait_list = ();
        my @profile_info = @$profile;
        my $projectprop_id = $profile_info[0];
        my $profile_name = $profile_info[1];
        my $profile_scope = $profile_info[2];
        my $profile_details = $profile_info[3];
        my $profile_submitter = $profile_info[4];
        my $uploaded_date = $profile_info[5];
        my $profile_name_link = qq{<a href = "/profile/$projectprop_id">$profile_name</a>};
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
        my $trait_string = join("<br>", @sort_trait_list);

        push @profile_summary, [$profile_name_link, $profile_scope, $trait_string, $profile_submitter, $uploaded_date] ;
    }
#    print STDERR "TRAIT LIST =".Dumper(\@profile_summary)."\n";

    $c->stash->{rest} = {data => \@profile_summary};

}


sub get_profile_detail :Path('/ajax/breeders/program/profile_detail') :Args(1) {
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


sub create_profile_template : Path('/ajax/program/create_profile_template') : ActionClass('REST') { }

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


sub upload_profile : Path('/ajax/breeders/program/upload_profile') : ActionClass('REST') { }
sub upload_profile_POST : Args(0) {
    my $self = shift;
    my $c = shift;
    my $user_id;
    my $user_name;
    my $user_role;
    my $session_id = $c->req->param("sgn_session_id");

    if ($session_id){
        my $dbh = $c->dbc->dbh;
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
    my $program_id = $c->req->param('profile_program_id');
    my $new_profile_name = $c->req->param('new_profile_name');
    my $new_profile_scope = $c->req->param('new_profile_scope');
    $new_profile_name =~ s/^\s+|\s+$//g;

    my $profile_obj = CXGN::BreedersToolbox::ProductProfile->new({ bcs_schema => $schema, parent_id => $program_id });
    my $profiles = $profile_obj->get_product_profile_info();
    my @db_profile_names;
    foreach my $profile(@$profiles){
        my @profile_info = @$profile;
        my $stored_profile_name = $profile_info[1];
        push @db_profile_names, $stored_profile_name;
    }
    if ($new_profile_name ~~ @db_profile_names){
        $c->stash->{rest} = {error=>'Please use different product profile name. This name is already used for another product profile!'};
        return;
    }

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

    my $profile = CXGN::BreedersToolbox::ProductProfile->new({ bcs_schema => $schema });
    $profile->product_profile_name($new_profile_name);
    $profile->product_profile_scope($new_profile_scope);
    $profile->product_profile_details($profile_detail_string);
    $profile->product_profile_submitter($user_name);
    $profile->product_profile_uploaded_date($uploaded_date);
    $profile->parent_id($program_id);
	my $project_prop_id = $profile->store_by_rank();

    if ($@) {
        $c->stash->{rest} = { error => $@ };
        print STDERR "An error condition occurred, was not able to upload profile. ($@).\n";
        $c->detach();
    }

    $c->stash->{rest} = { success => 1 };

}


sub get_autogenerated_name_metadata :Chained('ajax_breeding_program') PathPart('autogenerated_name_metadata') Args(0){
    my $self = shift;
    my $c = shift;
    my $program = $c->stash->{program};
    my $program_id = $program->get_program_id;
    my $schema = $c->stash->{schema};
    my $dbh = $c->dbc->dbh();

    my $projects = CXGN::BreedersToolbox::Projects->new({schema => $schema});
    my $return = $projects->get_autogenerated_name_metadata_by_breeding_program($program_id);
    my $name_metadata = $return->{name_metadata};

    my @autogenerated_name_metadata;

    foreach my $format_name (keys %$name_metadata) {
        my $description = $name_metadata->{$format_name}->{'description'};
        my $name_type = $name_metadata->{$format_name}->{'name_type'};
        my $name_attributes = $name_metadata->{$format_name}->{'name_attributes'};
        my @all_attributes = ();

        foreach my $attribute (@$name_attributes) {
            if (ref $attribute eq ref {}) {
                my %text_hash = %{$attribute};
                my $text = $text_hash{'text'};
                push @all_attributes, $text;
            } else {
                push @all_attributes, $attribute;
            }
        }
        my $attributes_string = join("_", @all_attributes);

        my $last_serial_number = $name_metadata->{$format_name}->{'last_serial_number'};
        my $added_by = $name_metadata->{$format_name}->{'added_by'};
        my $created_date = $name_metadata->{$format_name}->{'date'};

        my $person = CXGN::People::Person->new($dbh, $added_by);
        my $person_name = $person->get_first_name()." ".$person->get_last_name();

        push @autogenerated_name_metadata, [$format_name, $description, $name_type, $attributes_string, $last_serial_number, $person_name, $created_date];
    }

    $c->stash->{rest} = {data => \@autogenerated_name_metadata};

}


sub _parse_list_from_json {
    my $list_json = shift;
    my $json = JSON->new();

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
