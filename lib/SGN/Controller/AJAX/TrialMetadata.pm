
package SGN::Controller::AJAX::TrialMetadata;

use Moose;
use Data::Dumper;
use List::Util 'max';
use Bio::Chado::Schema;
use List::Util qw | any |;


BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );

has 'schema' => (
		 is       => 'rw',
		 isa      => 'DBIx::Class::Schema',
		 lazy_build => 1,
		);


sub trial : Chained('/') PathPart('ajax/breeders/trial') CaptureArgs(1) {
    my $self = shift;
    my $c = shift;
    my $trial_id = shift;

    $c->stash->{trial_id} = $trial_id;
    $c->stash->{schema} =  $c->dbic_schema("Bio::Chado::Schema");
    $c->stash->{trial} = CXGN::Trial->new( { bcs_schema => $c->stash->{schema}, trial_id => $trial_id });

    if (!$c->stash->{trial}) {
	$c->stash->{rest} = { error => "The specified trial with id $trial_id does not exist" };
	return;
    }

}

=head2 delete_trial_by_file

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub delete_trial_data : Local() ActionClass('REST');

sub delete_trial_data_GET : Chained('trial') PathPart('delete') Args(1) {
    my $self = shift;
    my $c = shift;
    my $datatype = shift;

    if ($self->delete_privileges_denied($c)) {
	$c->stash->{rest} = { error => "You have insufficient access privileges to delete trial data." };
	return;
    }

    my $error = "";

    if ($datatype eq 'phenotypes') {
	$error = $c->stash->{trial}->delete_phenotype_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));
	$error .= $c->stash->{trial}->delete_phenotype_data();
    }

    elsif ($datatype eq 'layout') {
	$error = $c->stash->{trial}->delete_metadata($c->dbic_schema("CXGN::Metadata::Schema"), $c->dbic_schema("CXGN::Phenome::Schema"));
	$error = $c->stash->{trial}->delete_field_layout();
    }
    elsif ($datatype eq 'entry') {
	$error = $c->stash->{trial}->delete_project_entry();
    }
    else {
	$c->stash->{rest} = { error => "unknown delete action for $datatype" };
	return;
    }
    if ($error) {
	$c->stash->{rest} = { error => $error };
	return;
    }
    $c->stash->{rest} = { message => "Successfully deleted trial data.", success => 1 };
}

sub trial_details : Chained('trial') PathPart('details') Args(0) ActionClass('REST') {};

sub trial_details_GET   {
    my $self = shift;
    my $c = shift;

    my $trial = $c->stash->{trial};

    $c->stash->{rest} = { details => $trial->get_details() };

}

sub trial_details_POST  {
    my $self = shift;
    my $c = shift;

    my @categories = $c->req->param("categories[]");

    my $details = {};
    foreach my $category (@categories) {
      $details->{$category} = $c->req->param("details[$category]");
    }

    if (!%{$details}) {
      $c->stash->{rest} = { error => "No values were edited, so no changes could be made for this trial's details." };
      return;
    }
    else {
    print STDERR "Here are the deets: " . Dumper($details) . "\n";
    }

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
	    $c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial details of this trial.' };
	    return;
    }

    my $trial_id = $c->stash->{trial_id};
    my $trial = $c->stash->{trial};
    my $program_object = CXGN::BreedersToolbox::Projects->new( { schema => $c->stash->{schema} });
    my $breeding_program = $program_object->get_breeding_programs_by_trial($trial_id);

    if (! ($c->user() &&  ($c->user->check_roles("curator") || $c->user->check_roles($breeding_program)))) {
	    $c->stash->{rest} = { error => "You need to be logged in with sufficient privileges to change the details of this trial." };
	    return;
    }

    # set each new detail that is defined
    eval {
      if ($details->{name}) { $trial->set_name($details->{name}); }
      if ($details->{breeding_program}) { $trial->set_breeding_program($details->{breeding_program}); }
      if ($details->{location}) { $trial->set_location($details->{location}); }
      if ($details->{year}) { $trial->set_year($details->{year}); }
      if ($details->{type}) { $trial->set_project_type($details->{type}); }
      if ($details->{planting_date}) {
        if ($details->{planting_date} eq 'remove') { $trial->remove_planting_date($trial->get_planting_date()); }
        else { $trial->set_planting_date($details->{planting_date}); }
      }
      if ($details->{harvest_date}) {
        if ($details->{harvest_date} eq 'remove') { $trial->remove_harvest_date($trial->get_harvest_date()); }
        else { $trial->set_harvest_date($details->{harvest_date}); }
      }
      if ($details->{description}) { $trial->set_description($details->{description}); }
    };

    if ($@) {
	    $c->stash->{rest} = { error => "An error occurred setting the new trial details: $@" };
    }
    else {
	    $c->stash->{rest} = { success => 1 };
    }
}

sub traits_assayed : Chained('trial') PathPart('traits_assayed') Args(0) {
    my $self = shift;
    my $c = shift;

    my @traits_assayed  = $c->stash->{trial}->get_traits_assayed();
    $c->stash->{rest} = { traits_assayed => \@traits_assayed };
}


sub phenotype_summary : Chained('trial') PathPart('phenotypes') Args(0) {
    my $self = shift;
    my $c = shift;

    my $dbh = $c->dbc->dbh();
    my $trial_id = $c->stash->{trial_id};

    my $h = $dbh->prepare("SELECT (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text AS trait, cvterm.cvterm_id, count(phenotype.value), to_char(avg(phenotype.value::real), 'FM999990.990'), to_char(max(phenotype.value::real), 'FM999990.990'), to_char(min(phenotype.value::real), 'FM999990.990'), to_char(stddev(phenotype.value::real), 'FM999990.990') FROM cvterm JOIN phenotype ON (cvterm_id=cvalue_id) JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_project USING(nd_experiment_id) JOIN dbxref ON cvterm.dbxref_id = dbxref.dbxref_id JOIN db ON dbxref.db_id = db.db_id WHERE project_id=? and phenotype.value~? GROUP BY (((cvterm.name::text || '|'::text) || db.name::text) || ':'::text) || dbxref.accession::text, cvterm.cvterm_id;");

    my $numeric_regex = '^[0-9]+([,.][0-9]+)?$';
    $h->execute($c->stash->{trial_id}, $numeric_regex );

    my @phenotype_data;
    while (my ($trait, $trait_id, $count, $average, $max, $min, $stddev) = $h->fetchrow_array()) {
	push @phenotype_data, [ qq{<a href="/cvterm/$trait_id/view">$trait</a>}, $average, $min, $max, $stddev, $count, qq{<a href="#raw_data_histogram_well" onclick="trait_summary_hist_change($trait_id)"><span class="glyphicon glyphicon-stats"></span></a>} ];
    }

    $c->stash->{rest} = { data => \@phenotype_data };
}

sub trait_histogram : Chained('trial') PathPart('trait_histogram') Args(1) {
    my $self = shift;
    my $c = shift;
    my $trait_id = shift;

    my @data = $c->stash->{trial}->get_phenotypes_for_trait($trait_id);

    $c->stash->{rest} = { data => \@data };
}

sub get_trial_folder :Chained('trial') PathPart('folder') Args(0) {
    my $self = shift;
    my $c = shift;

    if (!($c->user()->check_roles('curator') || $c->user()->check_roles('submitter'))) {
	$c->stash->{rest} = { error => 'You do not have the required privileges to edit the trial type of this trial.' };
	return;
    }

    my $project_parent = $c->stash->{trial}->get_folder();

    $c->stash->{rest} = { folder => [ $project_parent->project_id(), $project_parent->name() ] };

}

sub trial_accessions : Chained('trial') PathPart('accessions') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_accessions();

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_controls : Chained('trial') PathPart('controls') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_controls();

    $c->stash->{rest} = { accessions => \@data };
}

sub trial_plots : Chained('trial') PathPart('plots') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $trial = CXGN::Trial->new( { bcs_schema => $schema, trial_id => $c->stash->{trial_id} });

    my @data = $trial->get_plots();

    $c->stash->{rest} = { plots => \@data };
}

sub trial_design : Chained('trial') PathPart('design') Args(0) {
    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $layout = CXGN::Trial::TrialLayout->new({ schema => $schema, trial_id =>$c->stash->{trial_id} });

    my $design = $layout->get_design();
    my $design_type = $layout->get_design_type();
    my $plot_dimensions = $layout->get_plot_dimensions();

    my $plot_length = '';
    if ($plot_dimensions->[0]) {
	$plot_length = $plot_dimensions->[0];
    }

    my $plot_width = '';
    if ($plot_dimensions->[1]){
	$plot_width = $plot_dimensions->[1];
    }

    my $plants_per_plot = '';
    if ($plot_dimensions->[2]){
	$plants_per_plot = $plot_dimensions->[2];
    }

    my $block_numbers = $layout->get_block_numbers();
    my $number_of_blocks = '';
    if ($block_numbers) {
      $number_of_blocks = scalar(@{$block_numbers});
    }

    my $replicate_numbers = $layout->get_replicate_numbers();
    my $number_of_replicates = '';
    if ($replicate_numbers) {
      $number_of_replicates = scalar(@{$replicate_numbers});
    }

    $c->stash->{rest} = { design_type => $design_type, num_blocks => $number_of_blocks, num_reps => $number_of_replicates, plot_length => $plot_length, plot_width => $plot_width, plants_per_plot => $plants_per_plot, design => $design };
}

sub get_spatial_layout : Chained('trial') PathPart('coords') Args(0) {

    my $self = shift;
    my $c = shift;
    my $schema = $c->dbic_schema("Bio::Chado::Schema");

    my $layout = CXGN::Trial::TrialLayout->new(
	{
	    schema => $schema,
	    trial_id =>$c->stash->{trial_id}
	});

    my $design = $layout-> get_design();

    print STDERR Dumper($design);

    my @layout_info;
    foreach my $plot_number (keys %{$design}) {
	push @layout_info, {
			plot_id => $design->{$plot_number}->{plot_id},
			plot_number => $plot_number,
			row_number => $design->{$plot_number}->{row_number},
			col_number => $design->{$plot_number}->{col_number},
			block_number=> $design->{$plot_number}-> {block_number},
			rep_number =>  $design->{$plot_number}-> {rep_number},
			plot_name => $design->{$plot_number}-> {plot_name},
			accession_name => $design->{$plot_number}-> {accession_name},

	};

    }

	my @row_numbers = ();
	my @col_numbers = ();
	my @rep_numbers = ();
	my @block_numbers = ();
	my @accession_name = ();
	my @plot_name = ();
	my @plot_id = ();
	my @array_msg = ();
	my @plot_number = ();
	my $my_hash;

	foreach $my_hash (@layout_info) {
	    if ($my_hash->{'row_number'}) {
		if ($my_hash->{'row_number'} =~ m/\d+/) {
		$array_msg[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = "rep_number: ".$my_hash->{'rep_number'}."\nblock_number: ".$my_hash->{'block_number'}."\nrow_number: ".$my_hash->{'row_number'}."\ncol_number: ".$my_hash->{'col_number'}."\naccession_name: ".$my_hash->{'accession_name'};


	$plot_id[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'plot_id'};
	#$plot_id[$my_hash->{'plot_number'}] = $my_hash->{'plot_id'};
	$plot_number[$my_hash->{'row_number'}-1][$my_hash->{'col_number'}-1] = $my_hash->{'plot_number'};
	#$plot_number[$my_hash->{'plot_number'}] = $my_hash->{'plot_number'};

		}
		else {
		}
	    }
	}
 # Looping through the hash and printing out all the hash elements.

    foreach $my_hash (@layout_info) {
	push @col_numbers, $my_hash->{'col_number'};
	push @row_numbers, $my_hash->{'row_number'};
	#push @plot_id, $my_hash->{'plot_id'};
	#push @plot_number, $my_hash->{'plot_number'};
	push @rep_numbers, $my_hash->{'rep_number'};
	push @block_numbers, $my_hash->{'block_number'};
	push @accession_name, $my_hash->{'accession_name'};
	push @plot_name, $my_hash->{'plot_name'};

    }


    my $max_col = 0;
    $max_col = max( @col_numbers ) if (@col_numbers);
    print "$max_col\n";
    my $max_row = 0;
    $max_row = max( @row_numbers ) if (@row_numbers);
    print "$max_row\n";


	$c->stash->{rest} = { coord_row =>  \@row_numbers,
			      coords =>  \@layout_info,
			      coord_col =>  \@col_numbers,
			      max_row => $max_row,
			      max_col => $max_col,
			      plot_msg => \@array_msg,
			      rep => \@rep_numbers,
			      block => \@block_numbers,
			      accessions => \@accession_name,
			      plot_name => \@plot_name,
			      plot_id => \@plot_id,
			      plot_number => \@plot_number
	};

}


sub delete_privileges_denied {
    my $self = shift;
    my $c = shift;

    my $trial_id = $c->stash->{trial_id};

    if (! $c->user) { return "Login required for delete functions."; }
    my $user_id = $c->user->get_object->get_sp_person_id();

    if ($c->user->check_roles('curator')) {
	return 0;
    }

    my $breeding_programs = $c->stash->{trial}->get_breeding_programs();

    if ( ($c->user->check_roles('submitter')) && ( $c->user->check_roles($breeding_programs->[0]->[1]))) {
	return 0;
    }
    return "You have insufficient privileges to delete a trial.";
}

# loading field coordinates

sub upload_trial_coordinates : Path('/ajax/breeders/trial/coordsupload') Args(0) {

    my $self = shift;
    my $c = shift;

    if (!$c->user()) {
	print STDERR "User not logged in... not uploading coordinates.\n";
	$c->stash->{rest} = {error => "You need to be logged in to upload coordinates." };
	return;
    }

    if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
	$c->stash->{rest} = {error =>  "You have insufficient privileges to add coordinates." };
	return;
    }

    my $time = DateTime->now();
    my $user_id = $c->user()->get_object()->get_sp_person_id();
    my $user_name = $c->user()->get_object()->get_username();
    my $timestamp = $time->ymd()."_".$time->hms();
    my $subdirectory = 'trial_coords_upload';

    my $upload = $c->req->upload('trial_coordinates_uploaded_file');
    my $upload_tempfile  = $upload->tempname;

    my $upload_original_name  = $upload->filename();
    my $md5;

    my $uploader = CXGN::UploadFile->new();

    my %upload_metadata;


    # Store uploaded temporary file in archive
    print STDERR "TEMP FILE: $upload_tempfile\n";
    my $archived_filename_with_path = $uploader->archive($c, $subdirectory, $upload_tempfile, $upload_original_name, $timestamp);

    if (!$archived_filename_with_path) {
	$c->stash->{rest} = {error => "Could not save file $upload_original_name in archive",};
	return;
    }

    $md5 = $uploader->get_md5($archived_filename_with_path);
    unlink $upload_tempfile;

   # open file and remove return of line

     open(my $F, "<", $archived_filename_with_path) || die "Can't open archive file $archived_filename_with_path";
    my $schema = $c->dbic_schema("Bio::Chado::Schema");
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

    $c->stash->{rest} = {success => 1};


}

1;
