
=head1 NAME

SGN::Controller::AJAX::Trial - a REST controller class to provide the
backend for adding trials and viewing trials

=head1 DESCRIPTION

Creating and viewing trials

=head1 AUTHOR

Jeremy Edwards <jde22@cornell.edu>

=cut

package SGN::Controller::AJAX::Trial;

use Moose;

use List::MoreUtils qw /any /;
use Try::Tiny;
use CXGN::Phenome::Schema;
use CXGN::Chado::Stock;
use Scalar::Util qw(looks_like_number);
use File::Slurp;
use Data::Dumper;
use CXGN::TrialDesign;

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

sub generate_experimental_design : Path('/ajax/trial/generate_experimental_design') : ActionClass('REST') { }

sub generate_experimental_design_POST : Args(0) {
  my ($self, $c) = @_;
  my $stock_list_id = $c->req->param('stock_list');
  my $control_list_name = $c->req->param('list_of_checks_section_list_select');
  print STDERR "List: $stock_list_id\n";
#  print "first in list: $list[0] \n";
}


sub upload_trial_layout :  Path('/trial/upload_trial_layout') : ActionClass('REST') { }

sub upload_trial_layout_POST : Args(0) {
  my ($self, $c) = @_;
  my @contents;
  my $error = 0;
  my $upload = $c->req->upload('trial_upload_file');
  my $header_line;
  my @header_contents;
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

  if (!$c->user()) {  #user must be logged in
    $c->stash->{rest} = {error => "You need to be logged in to upload a file." };
    return;
  }

  if (!any { $_ eq "curator" || $_ eq "submitter" } ($c->user()->roles)  ) {  #user must have privileges to add a trial
    $c->stash->{rest} = {error =>  "You have insufficient privileges to upload a file." };
    return;
  }

  if (!$upload) { #upload file required
    $c->stash->{rest} = {error => "File upload failed: no file name received"};
    return;
  }

  try { #get file contents
    @contents = split /\n/, $upload->slurp;
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
    $error = 1;
  };
  if ($error) {return;}

  if (@contents < 2) { #upload file must contain at least one line of data plus a header
    $c->stash->{rest} = {error => "File upload failed: contains less than two lines"};
    return;
  }

  $header_line = shift(@contents);
  @header_contents = split /\t/, $header_line;

  try { #verify header contents
  _verify_trial_layout_header(\@header_contents);
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
    $error = 1;
  };
  if ($error) {return;}

  #verify location
  if (! $schema->resultset("NaturalDiversity::NdGeolocation")->find({description=>$c->req->param('add_project_location'),})){
    $c->stash->{rest} = {error => "File upload failed: location not found"};
    return;
    }


  try { #verify contents of file
  _verify_trial_layout_contents($self, $c, \@contents);
  } catch {
    my %error_hash = %{$_};
    print STDERR "the error hash:\n".Dumper(%error_hash)."\n";
    #my $error_string = Dumper(%error_hash);
    my $error_string = _formatted_string_from_error_hash(\%error_hash);

     $c->stash->{rest} = {error => "File upload failed: missing or invalid content (see details that follow..)", error_string => "$error_string"};
    $error = 1;
  };
  if ($error) {return;}

  print STDERR "adding to database\n";
  try { #add file contents to the database
    _add_trial_layout_to_database($self,$c,\@contents);
  } catch {
    $c->stash->{rest} = {error => "File upload failed: $_"};
    print "add error $_\n";
  };

  if ($error) {
    print "there was an error\n";
    return;
  } else {
     $c->stash->{rest} = {success => "1"};
  }



  print STDERR  "First line is:\n" . $contents[0] . "\n";
  print STDERR "You shouldn't see this if there is an error in the upload\n";
}

sub _add_trial_layout_to_database {
  my $self = shift;
  my $c = shift;
  my $contents_ref = shift;
  my @contents = @{$contents_ref};
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $year = $c->req->param('add_project_year');
  my $location = $c->req->param('add_project_location');
  my $project_name = $c->req->param('add_project_name');
  my $project_description = $c->req->param('add_project_description');

  print STDERR "loc: $location\n";

my $plot_cvterm = $schema->resultset("Cv::Cvterm")->create_with(
    { name   => 'plot',
      cv     => 'stock type',
      db     => 'null',
      dbxref => 'plot',
    });

my $geolocation = $schema->resultset("NaturalDiversity::NdGeolocation")->find_or_create(
    {
        description => $location, #add this as an option
    } ) ;

my $organism = $schema->resultset("Organism::Organism")->find_or_create(
    {
	genus   => 'Manihot',
	species => 'Manihot esculenta',
    } );



#???????????????????????
my $plot_exp_cvterm = $schema->resultset('Cv::Cvterm')->create_with(
    { name   => 'plot experiment',
      cv     => 'experiment type',
      db     => 'null',
      dbxref => 'plot experiment',
    });

  #create project
  my $project = $schema->resultset('Project::Project')->find_or_create(
	{
	    name => $project_name,
	 description => $location,
	}
	);

 my $projectprop_year = $project->create_projectprops( { 'project year' => $year,}, {autocreate=>1});

  print STDERR "sub for adding to database\n";
  print "project: $project_name\n";
  print "project desc: $project_description\n";




my $organism_id = $organism->organism_id();




  foreach my $content_line (@contents) {
    my @line_contents = split /\t/, $content_line;
    my $plot_name = $line_contents[0];
    my $block_number = $line_contents[1];
    my $rep_number = $line_contents[2];
    my $stock_name = $line_contents[3];
    my $stock;
    my $stock_rs = $schema->resultset("Stock::Stock")->search(
								{
								 -or => [
									 'lower(me.uniquename)' => { like => lc($stock_name) },
									 -and => [
										  'lower(type.name)'       => { like => '%synonym%' },
										  'lower(stockprops.value)' => { like => lc($stock_name) },
										 ],
									],
								},
								{
								 join => { 'stockprops' => 'type'} ,
								 distinct => 1
								}
							       );
      if ($stock_rs->count >1 ) {
	die ("multiple stocks found matching $stock_name");
      } elsif ($stock_rs->count == 1) {
	$stock = $stock_rs->first;
      } else {
	die ("no stocks found matching $stock_name");
      }


    my $unique_plot_name = $project_name."_".$stock_name."_plot_".$plot_name."_block_".$block_number."_rep_".$rep_number."_".$year."_".$location;

      my $plot = $schema->resultset("Stock::Stock")->find_or_create(
            { organism_id => $stock->organism_id(),
	      name       => $unique_plot_name,
	      uniquename => $unique_plot_name,
	      type_id => $plot_cvterm->cvterm_id,
            } );

    my $experiment = $schema->resultset('NaturalDiversity::NdExperiment')->create(
            {
                nd_geolocation_id => $geolocation->nd_geolocation_id(),
                type_id => $plot_exp_cvterm->cvterm_id(),
            } );

#link to the project
        $experiment->find_or_create_related('nd_experiment_projects', {
            project_id => $project->project_id()
                                            } );
        #link the experiment to the stock
        $experiment->find_or_create_related('nd_experiment_stocks' , {
            stock_id => $plot->stock_id(),
            type_id  =>  $plot_exp_cvterm->cvterm_id(),
                                            });

    }
}

sub _verify_trial_layout_header {
  my $header_content_ref = shift;
  my @header_contents = @{$header_content_ref};
  if ($header_contents[0] ne 'plot_name' ||
      $header_contents[1] ne 'block_number' ||
      $header_contents[2] ne 'rep_number' ||
      $header_contents[3] ne 'stock_name') {
    die ("Wrong column names in header\n");
  }
  if (@header_contents != 4) {
    die ("Wrong number of columns in header\n");
  }
  return;
}

sub _verify_trial_layout_contents {
  my $self = shift;
  my $c = shift;
  my $contents_ref = shift;
  my @contents = @{$contents_ref};
  my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');
  my $year = $c->req->param('add_project_year');
  my $location = $c->req->param('add_project_location');
  my $project_name = $c->req->param('add_project_name');
  my $line_number = 1;
  my %error_hash;
  my %plot_name_errors;
  my %block_number_errors;
  my %rep_number_errors;
  my %stock_name_errors;
  my %column_number_errors;
  foreach my $content_line (@contents) {
    print STDERR "verifying line $line_number\n";
    my @line_contents = split /\t/, $content_line;
    if (@line_contents != 4) {
      my $column_count = scalar(@line_contents);
      $column_number_errors{$line_number} = "Line $line_number: wrong number of columns, expected 4, found $column_count";
      $line_number++;
      print STDERR "count: $column_count\n";
      next;
    }
    my $plot_name = $line_contents[0];
    my $block_number = $line_contents[1];
    my $rep_number = $line_contents[2];
    my $stock_name = $line_contents[3];




    #if (! $schema->resultset("Stock::Stock")->find({name=>$stock_name,})){
    #  $stock_name_errors{$line_number} = "Line $line_number: stock name $stock_name not found";
    #}

    if (!$stock_name) {
      $stock_name_errors{$line_number} = "Line $line_number: stock name is missing";
    } else {
      my $stock_rs = $schema->resultset("Stock::Stock")->search( #make sure stock name exists and returns a unique result
								{
								 -or => [
									 'lower(me.uniquename)' => { like => lc($stock_name) },
									 -and => [
										  'lower(type.name)'       => { like => '%synonym%' },
										  'lower(stockprops.value)' => { like => lc($stock_name) },
										 ],
									],
								},
								{
								 join => { 'stockprops' => 'type'} ,
								 distinct => 1
								}
							       );
      if ($stock_rs->count >1 ) {
	print STDERR "ERROR: found multiple accessions for name $stock_name! \n";
	my $error_string = "Line $line_number:  multiple accessions found for stock name $stock_name (";
	while ( my $st = $stock_rs->next) {
	  print STDERR "stock name = " . $st->uniquename . "\n";
	  my $error_string .= $st->uniquename.",";
	}
	$stock_name_errors{$line_number} = $error_string;
      } elsif ($stock_rs->count == 1) {
	print STDERR "Found stock name $stock_name\n";
      } else {
	$stock_name_errors{$line_number} = "Line $line_number: stock name $stock_name not found";
      }
    }

    if (!$plot_name) {
      $plot_name_errors{$line_number} = "Line $line_number: plot name is missing";
    } else {
      my $unique_plot_name = $project_name."_".$stock_name."_plot_".$plot_name."_block_".$block_number."_rep_".$rep_number."_".$year."_".$location;
      print STDERR "Unique plot:  $unique_plot_name\n";
      if ($schema->resultset("Stock::Stock")->find({uniquename=>$unique_plot_name,})) {
	$plot_name_errors{$line_number} = "Line $line_number: plot name $unique_plot_name is not unique";
      }
    }

    #check for valid block number
    if (!$block_number) {
      $block_number_errors{$line_number} = "Line $line_number: block number is missing";
    } else {
      if (!($block_number =~ /^\d+?$/)) {
	$block_number_errors{$line_number} = "Line $line_number: block number $block_number is not an integer";
      } elsif ($block_number < 1 || $block_number > 1000000) {
	$block_number_errors{$line_number} = "Line $line_number: block number $block_number is out of range";
      }
    }

    #check for valid rep number
    if (!$rep_number) {
      $rep_number_errors{$line_number} = "Line $line_number: rep number is missing";
    } else {
      if (!($rep_number =~ /^\d+?$/)) {
	$rep_number_errors{$line_number} = "Line $line_number: rep number $rep_number is not an integer";
      } elsif ($rep_number < 1 || $rep_number > 1000000) {
	$rep_number_errors{$line_number} = "Line $line_number: rep number $block_number is out of range";
      }
    }

    $line_number++;
  }

  if (%plot_name_errors) {$error_hash{'plot_name_errors'}=\%plot_name_errors;}
  if (%block_number_errors) {$error_hash{'block_number_errors'}=\%block_number_errors;}
  if (%rep_number_errors) {$error_hash{'rep_number_errors'}=\%rep_number_errors;}
  if (%stock_name_errors) {$error_hash{'stock_name_errors'}=\%stock_name_errors;}
  if (%column_number_errors) {$error_hash{'column_number_errors'}=\%column_number_errors;}
  if (%error_hash) {
    die (\%error_hash);
  }
  return;
}


sub _formatted_string_from_error_hash {
  my $error_hash_ref = shift;
  my %error_hash = %{$error_hash_ref};
  my $error_string ;
  if ($error_hash{column_number_errors}) {
    $error_string .= "<b>Column number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{column_number_errors}})."<br><br>";
  }
  if ($error_hash{stock_name_errors}) {
    $error_string .= "<b>Stock name errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{stock_name_errors}})."<br><br>";
  }
  if ($error_hash{'plot_name_errors'}) {
    $error_string .= "<b>Plot name errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'plot_name_errors'}})."<br><br>";
  }
  if ($error_hash{'block_number_errors'}) {
    $error_string .= "<b>Block number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'block_number_errors'}})."<br><br>";
  }
  if ($error_hash{'rep_number_errors'}) {
    $error_string .= "<b>Rep number errors</b><br><br>"._formatted_string_from_error_hash_by_type(\%{$error_hash{'rep_number_errors'}})."<br><br>";
  }
  return $error_string;
}

sub _formatted_string_from_error_hash_by_type {
  my $error_hash_ref = shift;
  my %error_hash = %{$error_hash_ref};
  my $error_string;
  foreach my $key (sort { $a <=> $b} keys %error_hash) {
    $error_string .= $error_hash{$key} . "<br>";
  }
  return $error_string;
}


1;
