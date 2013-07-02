
=head1 NAME

SGN::Controller::AJAX::PhenotypesUpload - a REST controller class to provide the
backend for uploading phenotype spreadsheets

=head1 DESCRIPTION

Uploading Phenotype Spreadsheets

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>
Naama Menda <nm249@cornell.edu>

=cut

package SGN::Controller::AJAX::PhenotypesUpload;

use Moose;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Chado::Stock;
use Scalar::Util qw(looks_like_number);
use File::Basename;
use File::Slurp;
use File::Spec;
use File::Temp qw | tempfile |;
use List::MoreUtils qw /any /;
use SGN::View::ArrayElements qw(array_elements_simple_view);

#use Data::Dumper;
use CXGN::Stock::StockTemplate;
use JSON -support_by_pp;
#use SGN::View::Trial qw/design_layout_view design_info_view/;


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
sub _build_schema {
  shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}


sub upload_phenotype_spreadsheet :  Path('/ajax/phenotype/upload_spreadsheet') : ActionClass('REST') { }

sub upload_phenotype_spreadsheet_POST : Args(0) {
  my ($self, $c) = @_;
  my $error;
  my $stock_template = new CXGN::Stock::StockTemplate;
  my $upload = $c->req->upload('upload_phenotype_spreadsheet_file_input');
  my $upload_file_name;
  my $upload_file_temporary_directory;
  my $upload_file_temporary_full_path;

  my $archive_path = $c->config->{archive_path};
  if (!-d $archive_path) {
    mkdir $archive_path;
  }

  if (!$c->user()) {  #user must be logged in
    $c->stash->{rest} = {error => "You need to be logged in to upload a file." };
    return;
  }
  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {
    $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a file." };
    return;
  }
  if (!$upload) { #upload file required
    $c->stash->{rest} = {error => "File upload failed: no file name received"};
    return;
  }
  $upload_file_name = $upload->tempname;
  $upload_file_name =~ s/\/tmp\///;
  $upload_file_temporary_directory = $archive_path.'/tmp/';
  if (!-d $upload_file_temporary_directory) {
    mkdir $upload_file_temporary_directory;
  }
  $upload_file_temporary_full_path = $upload_file_temporary_directory.$upload_file_name;
  print "full path: $upload_file_temporary_full_path\n";
  write_file($upload_file_temporary_full_path, $upload->slurp);
  try {
    $stock_template->parse($upload_file_temporary_full_path);
  } catch {
    $c->stash->{rest} = {error => "Error parsing spreadsheet: $_"};
    $error=1;
  };
  if ($error) {
    return;
  }
  if ($stock_template->parse_errors()) {
    #my $parse_errors_string;
    #my @parse_errors = @{$stock_template->parse_errors()};
    my $parse_errors_html = array_elements_simple_view($stock_template->parse_errors());
    #foreach my $error_item (@parse_errors) {
    #  $parse_errors_string .= $error_item ."\n";
    #}
    $c->stash->{rest} = {error_list_html => $parse_errors_html };
    return;
  }


  #$upload_file_name =~ s/\/tmp\///;
  #print STDERR "temporary file name: $upload_file_name\n";
  #my $phenotype_spreadsheet_uri = $c->generated_file_uri('phenotype_spreadsheets', $upload_file_name);
  #my $spreadsheet_final_path = $c->path_to($phenotype_spreadsheet_uri);
  #write_file($spreadsheet_final_path, $upload->slurp);
}





# sub generate_experimental_design : Path('/ajax/trial/generate_experimental_design') : ActionClass('REST') { }

# sub generate_experimental_design_GET : Args(0) {
#   my ($self, $c) = @_;
#   my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#   my $trial_design = CXGN::TrialDesign->new();
#   my %design;
#   my %design_info;
#   my $error;
#   my $project_name = $c->req->param('project_name');
#   my $project_description = $c->req->param('project_description');
#   my $year = $c->req->param('year');
#   my @stock_names;
#   my $design_layout_view_html;
#   my $design_info_view_html;
#   if ($c->req->param('stock_list')) {
#     @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
#   }
#   my @control_names;
#   if ($c->req->param('control_list')) {
#     @control_names = @{_parse_list_from_json($c->req->param('control_list'))};
#   }
#   my $design_type =  $c->req->param('design_type');
#   my $rep_count =  $c->req->param('rep_count');
#   my $block_number =  $c->req->param('block_number');
#   my $block_size =  $c->req->param('block_size');
#   my $max_block_size =  $c->req->param('max_block_size');
#   my $plot_prefix =  $c->req->param('plot_prefix');
#   my $start_number =  $c->req->param('start_number');
#   my $increment =  $c->req->param('increment');
#   my $trial_location = $c->req->param('trial_location');

#   if (!$c->user()) {
#     $c->stash->{rest} = {error => "You need to be logged in to add a trial" };
#     return;
#   }

#   if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {  #user must have privileges to add a trial
#     $c->stash->{rest} = {error =>  "You have insufficient privileges to add a trial." };
#     return;
#   }

#   if (! $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=> $trial_location,})){
#     $c->stash->{rest} = {error => "Trial location not found"};
#     return;
#   }

#   if (@stock_names) {
#     $trial_design->set_stock_list(\@stock_names);
#     $design_info{'number_of_stocks'} = scalar(@stock_names);
#   } else {
#     $c->stash->{rest} = {error => "No list of stocks supplied." };
#     return;
#   }
#   if (@control_names) {
#     $trial_design->set_control_list(\@control_names);
#     $design_info{'number_of_controls'} = scalar(@control_names);
#   }
#   if ($start_number) {
#     $trial_design->set_plot_start_number($start_number);
#   } else {
#     $trial_design->set_plot_start_number(1);
#   }
#   if ($increment) {
#     $trial_design->set_plot_number_increment($increment);
#   } else {
#     $trial_design->set_plot_number_increment(1);
#   }
#   if ($plot_prefix) {
#     $trial_design->set_plot_name_prefix($plot_prefix);
#   }
#   if ($rep_count) {
#     $trial_design->set_number_of_reps($rep_count);
#   }
#   if ($block_number) {
#     $trial_design->set_number_of_blocks($block_number);
#   }
#   if ($block_size) {
#     $trial_design->set_block_size($block_size);
#   }
#   if ($max_block_size) {
#     $trial_design->set_maximum_block_size($max_block_size);
#   }
#   if ($design_type) {
#     $trial_design->set_design_type($design_type);
#     $design_info{'design_type'} = $design_type;
#   } else {
#     $c->stash->{rest} = {error => "No design type supplied." };
#     return;
#   }
#   if (!$trial_design->has_design_type()) {
#     $c->stash->{rest} = {error => "Design type not supported." };
#     return;
#   }
#   try {
#     $trial_design->calculate_design();
#   } catch {
#     $c->stash->{rest} = {error => "Could not calculate design: $_"};
#     $error=1;
#   };
#   if ($error) {return;}
#   if ($trial_design->get_design()) {
#     %design = %{$trial_design->get_design()};
#   } else {
#     $c->stash->{rest} = {error => "Could not generate design" };
#     return;
#   }
#   $design_layout_view_html = design_layout_view(\%design, \%design_info);
#   $design_info_view_html = design_info_view(\%design, \%design_info);
#   my $design_json = encode_json(\%design);
#   $c->stash->{rest} = {
# 		       success => "1", 
# 		       design_layout_view_html => $design_layout_view_html,
# 		       design_info_view_html => $design_info_view_html,
# 		       design_json => $design_json,
# 		      };
# }

# sub _parse_list_from_json {
#   my $list_json = shift;
#   my $json = new JSON;
#   if ($list_json) {
#     my $decoded_list = $json->allow_nonref->utf8->relaxed->escape_slash->loose->allow_singlequote->allow_barekey->decode($list_json);
#     #my $decoded_list = decode_json($list_json);
#     my @array_of_list_items = @{$decoded_list};
#     my @list;
#     foreach my $list_item_array_ref (@array_of_list_items) {
#       my @list_item_array = @{$list_item_array_ref};
#       push (@list,$list_item_array[1]);
#     }
#     return \@list;
#   }
#   else {
#     return;
#   }
# }

# sub commit_experimental_design : Path('/ajax/trial/commit_experimental_design') : ActionClass('REST') { }

# sub commit_experimental_design_GET : Args(0) {
#   my ($self, $c) = @_;
#   my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#   my $trial_design = CXGN::TrialDesign->new();
#   my %design;
#   my $error;
#   my $project_name = $c->req->param('project_name');
#   my $project_description = $c->req->param('project_description');
#   my $year = $c->req->param('year');
#   my @stock_names;
#   my $trial_location = $c->req->param('trial_location');
#   my $design_type =  $c->req->param('design_type');
#   if ($c->req->param('stock_list')) {
#     @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
#   }
#   my @control_names;
#   if ($c->req->param('control_list')) {
#     @control_names = @{_parse_list_from_json($c->req->param('control_list'))};
#   }
#   if ($c->req->param('design_json')) {
#     %design = %{_parse_design_from_json($c->req->param('design_json'))};
#   }
#   my $trial_name = "Trial $trial_location $year"; #need to add something to make unique in case of multiple trials in location per year.
#   my $accession_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
#     { name   => 'accession',
#       cv     => 'stock type',
#       db     => 'null',
#       dbxref => 'accession',
#     });
#   my $plot_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
#     { name   => 'plot',
#       cv     => 'stock type',
#       db     => 'null',
#       dbxref => 'plot',
#     });
#   my $plot_of = $schema->resultset("Cv::Cvterm")->create_with(
#     { name   => 'plot_of',
#       cv     => 'stock relationship',
#       db     => 'null',
#       dbxref => 'plot_of',
#     });
#   my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create(
#     {
#         description => $trial_location,
#     } ) ;

#   #create project
#   my $project = $schema->resultset('Project::Project')->find_or_create(
# 								       {
# 									name => $trial_name,
# 									description => $project_description,
# 								       }
# 								      );
#   $project->create_projectprops( { 'project year' => $year,'design' => $design_type}, {autocreate=>1});

#   #find the cvterm for a phenotyping experiment
#   my $pheno_cvterm = $schema->resultset('Cv::Cvterm')
#     ->create_with({
# 		   name   => 'phenotyping experiment',
# 		   cv     => 'experiment type',
# 		   db     => 'null',
# 		   dbxref => 'phenotyping experiment',
# 		  });

#   foreach my $key (sort { $a <=> $b} keys %design) {
#     my $plot_name = $design{$key}->{plot_name};
#     my $stock_name = $design{$key}->{stock_name};
#     my $block_number;
#     if ($design{$key}->{block_number}) {
#       $block_number = $design{$key}->{block_number};
#     } else {
#       $block_number = 1;
#     }
#     my $rep_number;
#     if ($design{$key}->{rep_number}) {
#       $rep_number = $design{$key}->{rep_number};
#     } else {
#       $rep_number = 1;
#     }
#     my $is_a_control = $design{$key}->{is_a_control};
#     my $plot_unique_name = $stock_name."_replicate:".$rep_number."_block:".$block_number."_plot:".$plot_name."_".$year."_".$trial_location;
#     my $plot;
#     my $parent_stock;
#     my $stock_rs = $schema->resultset("Stock::Stock")
#       ->search({
# 		-or => [
# 			'lower(me.uniquename)' => { like => lc($stock_name) },
# 			-and => [
# 				 'lower(type.name)'       => { like => '%synonym%' },
# 				 'lower(stockprops.value)' => { like => lc($stock_name) },
# 				],
# 		       ],
# 	       },
# 	       {
# 		join => { 'stockprops' => 'type'} ,
# 		distinct => 1
# 	       }
# 	      );
#       if ($stock_rs->count >1 ) {
# 	die ("multiple stocks found matching $stock_name");
#       } elsif ($stock_rs->count == 1) {
# 	$parent_stock = $stock_rs->first;
#       } else {
# 	die ("no stocks found matching $stock_name");
#       }

#     #create the plot
#     $plot = $schema->resultset("Stock::Stock")
#       ->find_or_create({
# 			organism_id => $parent_stock->organism_id(),
# 			name       => $plot_unique_name,
# 			uniquename => $plot_unique_name,
# 			type_id => $plot_cvterm->cvterm_id,
# 		       } );

#     if ($rep_number) {
#       $plot->stockprops({'replicate' => $rep_number}, {autocreate => 1} );
#     }
#     if ($block_number) {
#       $plot->stockprops({'block' => $block_number}, {autocreate => 1} );
#     }
#     $plot->stockprops({'plot number' => $key}, {autocreate => 1});
#     if ($is_a_control) {
#       $plot->stockprops({'is a control' => $is_a_control}, {autocreate => 1} );
#     }

#     #create the stock_relationship with the accession
#     $parent_stock
#       ->find_or_create_related('stock_relationship_objects',
# 			       {
# 				type_id => $plot_of->cvterm_id(),
# 				subject_id => $plot->stock_id(),
# 			       } );

#     my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
#       ->create({
# 		nd_geolocation_id => $geolocation->nd_geolocation_id(),
# 		type_id => $pheno_cvterm->cvterm_id(),
# 		});

#     #link to the project
#     $experiment->find_or_create_related('nd_experiment_projects',{project_id => $project->project_id()});

#     #link the experiment to the stock
#     $experiment->find_or_create_related('nd_experiment_stocks' , {
# 								  stock_id => $plot->stock_id(),
# 								  type_id  =>  $pheno_cvterm->cvterm_id(),
# 								 });
#   }
#   $c->stash->{rest} = {success => "1",};
# }

# sub _parse_design_from_json {
#   my $design_json = shift;
#   if ($design_json) {
#     my $decoded_json = decode_json($design_json);
#     my %design = %{$decoded_json};
#     return \%design;
#   }
#   else {
#     return;
#   }
# }

# sub verify_stock_list : Path('/ajax/trial/verify_stock_list') : ActionClass('REST') { }

# sub verify_stock_list_GET : Args(0) {
#   my ($self, $c) = @_;
#   my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#   my @stock_names;
#   my $error;
#   my %errors;
#   my $error_alert;
#   if ($c->req->param('stock_list')) {
#     @stock_names = @{_parse_list_from_json($c->req->param('stock_list'))};
#   }
#   if (!@stock_names) {
#     $c->stash->{rest} = {error => "No stock names supplied"};
#     return;
#   }
#   foreach my $stock_name (@stock_names) {
#     try {
#       _verify_stock($self,$c,$schema,$stock_name);
#     } catch {
#       $errors{$stock_name} = $_};
#     };
#   if (%errors) {
#     foreach my $key (keys %errors) {
#       $error_alert .= "Stock $key: ".$errors{$key}."\n";
#     }
#     $c->stash->{rest} = {error => $error_alert};
#   } else {
#     $c->stash->{rest} = {
# 		       success => "1",
# 		      };
#   }
# }

# sub _verify_stock {
#   my $self = shift;
#   my $c = shift;
#   my $schema = shift;
#   my $stock_name = shift;
#   my $stock_rs = $schema->resultset("Stock::Stock")
#     ->search({
# 	      -or => [
# 		      'lower(me.uniquename)' => { like => lc($stock_name) },
# 		      -and => [
# 			       'lower(type.name)' => { like => '%synonym%' },
# 			       'lower(stockprops.value)' => { like => lc($stock_name) },
# 			      ],
# 		     ],
# 	     },
# 	     {
# 	      join => { 'stockprops' => 'type'} ,
# 	      distinct => 1
# 	     }
# 	    );
#   if ($stock_rs->count >1 ) {
#     die ("Multiple stocks found matching $stock_name\n");
#   } elsif ($stock_rs->count == 1) {
#     $stock_name = $stock_rs->first;
#   } else {
#     die ("No stocks found matching $stock_name\n");
#   }
# }

# sub upload_trial_layout :  Path('/trial/upload_trial_layout') : ActionClass('REST') { }

# sub upload_trial_layout_POST : Args(0) {
#   my ($self, $c) = @_;
#   my @contents;
#   my $error = 0;
#   my $upload = $c->req->upload('trial_upload_file');
#   my $header_line;
#   my @header_contents;
#   my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#   if (!$c->user()) {  #user must be logged in
#     $c->stash->{rest} = {error => "You need to be logged in to upload a file." };
#     return;
#   }
#   if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {  #user must have privileges to add a trial
#     $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a file." };
#     return;
#   }
#   if (!$upload) { #upload file required
#     $c->stash->{rest} = {error => "File upload failed: no file name received"};
#     return;
#   }
#   try { #get file contents
#     @contents = split /\n/, $upload->slurp;
#   } catch {
#     $c->stash->{rest} = {error => "File upload failed: $_"};
#     $error = 1;
#   };
#   if ($error) {return;}
#   if (@contents < 2) { #upload file must contain at least one line of data plus a header
#     $c->stash->{rest} = {error => "File upload failed: contains less than two lines"};
#     return;
#   }
#   $header_line = shift(@contents);
#   @header_contents = split /\t/, $header_line;
#   try { #verify header contents
#   _verify_trial_layout_header(\@header_contents);
#   } catch {
#     $c->stash->{rest} = {error => "File upload failed: $_"};
#     $error = 1;
#   };
#   if ($error) {return;}

#   #verify location
#   if (! $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$c->req->param('add_project_location'),})){
#     $c->stash->{rest} = {error => "File upload failed: location not found"};
#     return;
#   }

#   try { #verify contents of file
#   _verify_trial_layout_contents($self, $c, \@contents);
#   } catch {
#     my %error_hash = %{$_};
#     #my $error_string = Dumper(%error_hash);
#     my $error_string = _formatted_string_from_error_hash(\%error_hash);
#     $c->stash->{rest} = {error => "File upload failed: missing or invalid content (see details that follow..)", error_string => "$error_string"};
#     $error = 1;
#   };
#   if ($error) {return;}

#   try { #add file contents to the database
#     _add_trial_layout_to_database($self,$c,\@contents);
#   } catch {
#     $c->stash->{rest} = {error => "File upload failed: $_"};
#   };

#   if ($error) {
#     return;
#   } else {
#      $c->stash->{rest} = {success => "1"};
#   }
# }

# sub _add_trial_layout_to_database {
#   my $self = shift;
#   my $c = shift;
#   my $contents_ref = shift;
#   my @contents = @{$contents_ref};
#   my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#   my $year = $c->req->param('add_project_year');
#   my $location = $c->req->param('add_project_location');
#   my $project_name = $c->req->param('add_project_name');
#   my $project_description = $c->req->param('add_project_description');
#   my $plot_cvterm = $schema->resultset("Cv::Cvterm")
#     ->create_with({
# 		   name   => 'plot',
# 		   cv     => 'stock type',
# 		   db     => 'null',
# 		   dbxref => 'plot',
# 		  });
#   my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")
#     ->find_or_create({
# 		      description => $location, #add this as an option
# 		     });
#   my $organism = $schema->resultset("Organism::Organism")
#     ->find_or_create({
# 		      genus   => 'Manihot',
# 		      species => 'Manihot esculenta',
# 		     });

#   #this is wrong
#   my $plot_exp_cvterm = $schema->resultset('Cv::Cvterm')
#     ->create_with({
# 		   name   => 'plot experiment',
# 		   cv     => 'experiment type',
# 		   db     => 'null',
# 		   dbxref => 'plot experiment',
# 		  });

#   #create project
#   my $project = $schema->resultset('Project::Project')
#     ->find_or_create({
# 		      name => $project_name,
# 		      description => $location,
# 		     }
# 		    );

#   my $projectprop_year = $project->create_projectprops( { 'project year' => $year,}, {autocreate=>1});
#   my $organism_id = $organism->organism_id();

#   foreach my $content_line (@contents) {
#     my @line_contents = split /\t/, $content_line;
#     my $plot_name = $line_contents[0];
#     my $block_number = $line_contents[1];
#     my $rep_number = $line_contents[2];
#     my $stock_name = $line_contents[3];
#     my $stock;
#     my $stock_rs = $schema->resultset("Stock::Stock")
#       ->search({
# 		-or => [
# 			'lower(me.uniquename)' => { like => lc($stock_name) },
# 			-and => [
# 				 'lower(type.name)'       => { like => '%synonym%' },
# 				 'lower(stockprops.value)' => { like => lc($stock_name) },
# 				],
# 		       ],
# 	       },
# 	       {
# 		join => { 'stockprops' => 'type'} ,
# 		distinct => 1
# 	       }
# 	      );
#     if ($stock_rs->count >1 ) {
#       die ("multiple stocks found matching $stock_name");
#     } elsif ($stock_rs->count == 1) {
#       $stock = $stock_rs->first;
#     } else {
#       die ("no stocks found matching $stock_name");
#     }
#     my $unique_plot_name = 
#       $project_name."_".$stock_name."_plot_".$plot_name."_block_".$block_number."_rep_".$rep_number."_".$year."_".$location;
#     my $plot = $schema->resultset("Stock::Stock")
#       ->find_or_create({
# 			organism_id => $stock->organism_id(),
# 			name       => $unique_plot_name,
# 			uniquename => $unique_plot_name,
# 			type_id => $plot_cvterm->cvterm_id,
# 		       });
#     my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')
#       ->create({
#                 nd_geolocation_id => $geolocation->nd_geolocation_id(),
#                 type_id => $plot_exp_cvterm->cvterm_id(),
# 	       });
#     #link to the project
#     $experiment
#       ->find_or_create_related('nd_experiment_projects',{
# 							 project_id => $project->project_id()
# 							});
#     #link the experiment to the stock
#     $experiment
#       ->find_or_create_related('nd_experiment_stocks' ,{
# 							stock_id => $plot->stock_id(),
# 							type_id  =>  $plot_exp_cvterm->cvterm_id(),
# 						       });
#     }
# }

# sub _verify_trial_layout_header {
#   my $header_content_ref = shift;
#   my @header_contents = @{$header_content_ref};
#   if ($header_contents[0] ne 'plot_name' ||
#       $header_contents[1] ne 'block_number' ||
#       $header_contents[2] ne 'rep_number' ||
#       $header_contents[3] ne 'stock_name') {
#     die ("Wrong column names in header\n");
#   }
#   if (@header_contents != 4) {
#     die ("Wrong number of columns in header\n");
#   }
#   return;
# }

# sub _verify_trial_layout_contents {
#   my $self = shift;
#   my $c = shift;
#   my $contents_ref = shift;
#   my @contents = @{$contents_ref};
#   my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
#   my $year = $c->req->param('add_project_year');
#   my $location = $c->req->param('add_project_location');
#   my $project_name = $c->req->param('add_project_name');
#   my $line_number = 1;
#   my %error_hash;
#   my %plot_name_errors;
#   my %block_number_errors;
#   my %rep_number_errors;
#   my %stock_name_errors;
#   my %column_number_errors;
#   foreach my $content_line (@contents) {
#     my @line_contents = split /\t/, $content_line;
#     if (@line_contents != 4) {
#       my $column_count = scalar(@line_contents);
#       $column_number_errors{$line_number} = "Line $line_number: wrong number of columns, expected 4, found $column_count";
#       $line_number++;
#       next;
#     }
#     my $plot_name = $line_contents[0];
#     my $block_number = $line_contents[1];
#     my $rep_number = $line_contents[2];
#     my $stock_name = $line_contents[3];
#     if (!$stock_name) {
#       $stock_name_errors{$line_number} = "Line $line_number: stock name is missing";
#     } else {
#       #make sure stock name exists and returns a unique result
#       my $stock_rs = $schema->resultset("Stock::Stock")
# 	->search({
# 		  -or => [
# 			  'lower(me.uniquename)' => { like => lc($stock_name) },
# 			  -and => [
# 				   'lower(type.name)'       => { like => '%synonym%' },
# 				   'lower(stockprops.value)' => { like => lc($stock_name) },
# 				  ],
# 			 ],
# 		 },
# 		 {
# 		  join => { 'stockprops' => 'type'} ,
# 		  distinct => 1
# 		 }
# 		);
#       if ($stock_rs->count >1 ) {
# 	my $error_string = "Line $line_number:  multiple accessions found for stock name $stock_name (";
# 	while ( my $st = $stock_rs->next) {
# 	  my $error_string .= $st->uniquename.",";
# 	}
# 	$stock_name_errors{$line_number} = $error_string;
#       } elsif ($stock_rs->count == 1) {
#       } else {
# 	$stock_name_errors{$line_number} = "Line $line_number: stock name $stock_name not found";
#       }
#     }

#     if (!$plot_name) {
#       $plot_name_errors{$line_number} = "Line $line_number: plot name is missing";
#     } else {
#       my $unique_plot_name = $project_name."_".$stock_name."_plot_".$plot_name."_block_".$block_number."_rep_".$rep_number."_".$year."_".$location;
#       if ($schema->resultset("Stock::Stock")->find({uniquename=>$unique_plot_name,})) {
# 	$plot_name_errors{$line_number} = "Line $line_number: plot name $unique_plot_name is not unique";
#       }
#     }

#     #check for valid block number
#     if (!$block_number) {
#       $block_number_errors{$line_number} = "Line $line_number: block number is missing";
#     } else {
#       if (!($block_number =~ /^\d+?$/)) {
# 	$block_number_errors{$line_number} = "Line $line_number: block number $block_number is not an integer";
#       } elsif ($block_number < 1 || $block_number > 1000000) {
# 	$block_number_errors{$line_number} = "Line $line_number: block number $block_number is out of range";
#       }
#     }

#     #check for valid rep number
#     if (!$rep_number) {
#       $rep_number_errors{$line_number} = "Line $line_number: rep number is missing";
#     } else {
#       if (!($rep_number =~ /^\d+?$/)) {
# 	$rep_number_errors{$line_number} = "Line $line_number: rep number $rep_number is not an integer";
#       } elsif ($rep_number < 1 || $rep_number > 1000000) {
# 	$rep_number_errors{$line_number} = "Line $line_number: rep number $block_number is out of range";
#       }
#     }
#     $line_number++;
#   }

#   if (%plot_name_errors) {$error_hash{'plot_name_errors'}=\%plot_name_errors;}
#   if (%block_number_errors) {$error_hash{'block_number_errors'}=\%block_number_errors;}
#   if (%rep_number_errors) {$error_hash{'rep_number_errors'}=\%rep_number_errors;}
#   if (%stock_name_errors) {$error_hash{'stock_name_errors'}=\%stock_name_errors;}
#   if (%column_number_errors) {$error_hash{'column_number_errors'}=\%column_number_errors;}
#   if (%error_hash) {
#     die (\%error_hash);
#   }
#   return;
# }

# sub _formatted_string_from_error_hash {
#   my $error_hash_ref = shift;
#   my %error_hash = %{$error_hash_ref};
#   my $error_string ;
#   if ($error_hash{column_number_errors}) {
#     $error_string .= "<b>Column number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{column_number_errors}})."<br><br>";
#   }
#   if ($error_hash{stock_name_errors}) {
#     $error_string .= "<b>Stock name errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{stock_name_errors}})."<br><br>";
#   }
#   if ($error_hash{'plot_name_errors'}) {
#     $error_string .= "<b>Plot name errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'plot_name_errors'}})."<br><br>";
#   }
#   if ($error_hash{'block_number_errors'}) {
#     $error_string .= "<b>Block number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'block_number_errors'}})."<br><br>";
#   }
#   if ($error_hash{'rep_number_errors'}) {
#     $error_string .= "<b>Rep number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'rep_number_errors'}})."<br><br>";
#   }
#   return $error_string;
# }

# sub _formatted_string_from_error_hash_by_type {
#   my $error_hash_ref = shift;
#   my %error_hash = %{$error_hash_ref};
#   my $error_string;
#   foreach my $key (sort { $a <=> $b} keys %error_hash) {
#     $error_string .= $error_hash{$key} . "<br>";
#   }
#   return $error_string;
# }


1;
