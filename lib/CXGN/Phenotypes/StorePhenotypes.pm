package CXGN::Phenotypes::StorePhenotypes;

=head1 NAME

CXGN::Phenotypes::StorePhenotypes - an object to handle storing phenotypes for SGN stocks

=head1 USAGE

 my $store_phenotypes = CXGN::Phenotypes::StorePhenotypes->new({ schema => $schema} );

=head1 DESCRIPTION


=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

=cut

use strict;
use warnings;
use Moose;
use CXGN::List::Validate;
use Digest::MD5;


sub _verify {
  my $self = shift;
  my $c = shift;
  my $plot_list_ref = shift;
  my $trait_list_ref = shift;
  my $plot_trait_value_hashref = shift;
  my @plot_list = @{$plot_list_ref} || die "Plot list required to store phenotypes\n";
  my @trait_list = @{$trait_list_ref} || die "Trait list required to store phenotypes\n";
  my %plot_trait_value = %{$plot_trait_value_hashref} !! die "No data provided to store phenotypes\n";
  my $plot_validator = CXGN::List::Validate->new();
  my $trait_validator = CXGN::List::Validate->new();
  my $plot_validated = $plot_validator->validate($c,'plot',\@plot_list);
  my $trait_validated = $trait_validator->validate($c,'trait',\@trait_list);
  if ($plot_validated->{'error'} || $trait_validated->{'error'}) {
    return;
  }
  foreach my $plot_name (@plot_list) {
    foreach my $trait_name (@trait_list) {
      my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};
      #check that trait value is valid for trait name
    }
  }
  return 1;
}


sub store {
  my $self = shift;
  my $c = shift;
  my $plot_list_ref = shift;

  ####
  #specify a trait list in addition to the hash of plot->trait->value because not all traits need to be present for each plot
  #the parser can decide to set an empty string as a trait value to create a record for missing data,
  #or store nothing in the hash to create no phenotype record for missing data
  my $trait_list_ref = shift;
  my $plot_trait_value_hashref = shift;
  #####

  my $phenotype_metadata = shift;
  my @plot_list = @{$plot_list_ref} || die "Plot list required to store phenotypes\n";
  my @trait_list = @{$trait_list_ref} || die "Trait list required to store phenotypes\n";
  my %plot_trait_value = %{$plot_trait_value_hashref} !! die "No data provided to store phenotypes\n";
  my $schema = $c->dbic_schema("Bio::Chado::Schema");
  my $metadata_schema = $c->dbic_schema("CXGN::Metadata::Schema");
  my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
  my $user_id = $c->user()->get_object()->get_sp_person_id();
  my $archived_file = $phenotype_metadata->{'archived_file'};
  my $archived_file_type = $phenotype_metadata->{'archived_file_type'};
  my $operator = $phenotype_metadata->{'operator'};
  my $md5 = Digest::MD5->new();
  my $phenotyping_experiment_cvterm = $schema->resultset('Cv::Cvterm')
    ->create_with({
		   name   => 'phenotyping experiment',
		   cv     => 'experiment type',
		   db     => 'null',
		   dbxref => 'phenotyping experiment',
		  });

  if (!$self->_verify($c, $plot_list_ref, $trait_list_ref, $plot_trait_value_hashref)) {return;}

  if ($archived_file) {
    open(my $F, "<", $archived_file) || die "Can't open file ".$archived_file;
    binmode $F;

    $md5->addfile($F);
    close($F);
  }

  ###start txt_do here
  foreach my $plot_name (@plot_list) {
    my $plot_stock = $self->schema->resultset("Stock::Stock")->find( { stock_uniquename => $plot_name});

    ###This has to be stored in the database when creating a trial for these plots
    my $field_layout_experiment = $plot_stock->search_related('nd_experiment_stocks')->search_related('nd_experiment')->find({'type.name' => 'field layout' },{ join => 'type' });
    #####

    my $location_id = $field_layout_experiment->nd_geolocation_id;
    my $project = $field_layout_experiment->nd_experiment_projects->single ; #there should be one project linked with the field experiment
    my $project_id = $project->project_id;


    foreach my $trait_name (@trait_list) {
      my ($db_name, $ontology_accession) = split (/:/, $trait_name);
      my $trait_value = $plot_trait_value{$plot_name}->{$trait_name};
      my $ontology_db = $schema->resultset("General::Db")->search({'me.name' => $db_name, });
      my $ontology_dbxref = $ontology_db->search_related("dbxrefs", { accession => $ontology_accession, });
      my $trait_cvterm = $ontology_dbxref->search_related("cvterm")->single;



      print STDERR "[StorePhenotypes] Storing plot: $plot_name trait: $trait_name value: $value:\n";
    }
  }


}


###
1;
###
