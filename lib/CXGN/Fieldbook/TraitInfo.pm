package CXGN::Fieldbook::TraitInfo;

=head1 NAME

CXGN::Fieldbook::TraitInfo - a module to get information from a trait to build the fieldbook trait file.

=head1 USAGE

 my $trait_info_lookup = CXGN::Fieldbook::TraitInfo->new({ chado_schema => $chado_schema, db_name => $db_name, trait_accession => $trait_accession });
 my $trait_info = $trait_info_lookup->get_trait_info();  #returns a string to use for the fieldbook trait file or returns false if not found

=head1 DESCRIPTION

Looks up a trait and builds a string to use in the fieldbook trait file.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)
 Naama Menda (nm249@cornell.edu)

=cut

use Moose;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

has 'chado_schema' => (
		 is       => 'ro',
		 isa      => 'DBIx::Class::Schema',
		 required => 1,
		);
has 'db_name' => (
		  is => 'ro',
		  isa => 'Str',
		  required => 1,
		 );
has 'trait_accession' => (
		  is => 'ro',
		  isa => 'Str',
		  required => 1,
		 );

sub get_trait_info {
  my $self = shift;
  my $chado_schema = $self->get_chado_schema();
  my $trait_info_string;

  my $db_rs = $chado_schema->resultset("General::Db")->search( { 'me.name' => $self->get_db_name() });

  if (!$db_rs) {
    print STDERR "Could not find trait ontology database: ".$self->get_db_name()."\n";
    return;
  }

  my $trait_cvterm = $chado_schema->resultset("Cv::Cvterm")
    ->find( {
	     'dbxref.db_id'     => $db_rs->first()->db_id(),
	     'dbxref.accession' => $self->get_trait_accession(),
	    },
	    {
	     'join' => 'dbxref'
	    }
	  );


  if (!$trait_cvterm) {
    print STDERR "Could not find trait name: ".$self->get_trait_name()."\n";
    return;
  }

  #get cvtermprops
  my $cvtermprops = $trait_cvterm->search_related('cvtermprops');

  my $cvterms = $self->_get_cvterms();

  my %trait_props;
  #set default values
  $trait_props{'trait_format'}='text';
  $trait_props{'trait_default_value'}='';
  $trait_props{'trait_minimum'}='';
  $trait_props{'trait_maximum'}='';
  $trait_props{'trait_details'}='';
  $trait_props{'trait_categories'}='';



  foreach my $property_name (keys %{$cvterms}) {
    my $prop_cvterm = $cvterms->{$property_name};
    my $prop = $cvtermprops->find({'type_id' => $prop_cvterm->cvterm_id()});
    if ($prop  && $prop->value()) {
      $trait_props{$property_name}=$prop->value();
    }
  }

  #build trait_info_string
  #order for trait file is: format,defaultValue,minimum,maximum,details,categories
  $trait_info_string .= '"'.$trait_props{'trait_format'}.'",';
  $trait_info_string .= '"'.$trait_props{'trait_default_value'}.'",';
  $trait_info_string .= '"'.$trait_props{'trait_minimum'}.'",';
  $trait_info_string .= '"'.$trait_props{'trait_maximum'}.'",';
  $trait_info_string .= '"'.$trait_props{'trait_details'}.'",';
  $trait_info_string .= '"'.$trait_props{'trait_categories'}.'"';

  return $trait_info_string;
}

sub _get_cvterms {
  my $self = shift;
  my $chado_schema = $self->get_chado_schema();
  my %cvterms;

  my @trait_property_names = qw(
			     trait_format
			     trait_default_value
			     trait_minimum
			     trait_maximum
			     trait_details
			     trait_categories
			  );

  # my $cv = $chado_schema->resultset("Cv::Cv")
  #   ->find_or_create({
  # 		   name => 'trait_property',
  # 		  });
  # $cv->insert;

  foreach my $property_name (@trait_property_names) {

    $cvterms{$property_name} = $chado_schema->resultset("Cv::Cvterm")
      ->create_with({
		     name   => $property_name,
		     cv     => 'trait_property',
		     db     => 'null',
		     dbxref => $property_name,
		    });
  }

  return \%cvterms;

}


#######
1;
#######
