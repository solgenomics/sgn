package CXGN::Fieldbook::TraitInfo;

=head1 NAME

CXGN::Fieldbook::TraitInfo - a module to get information from a trait to build the fieldbook trait file.

=head1 USAGE

 my $trait_info_lookup = CXGN::Fieldbook::TraitInfo->new({ chado_schema => $chado_schema, db_name => $db_name, trait_name => $trait_name );
 my $trait_info = $trait_info_lookup->get_trait_info();  #returns a string to use for the fieldbook trait file or returns false if not found

=head1 DESCRIPTION

Looks up a trait and builds a string to use in the fieldbook trait file.

=head1 AUTHORS

 Jeremy D. Edwards (jde22@cornell.edu)

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
has 'trait_name' => (
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

  my $trait_cvterm = $schema->resultset("Cv::Cvterm")
    ->find( {
	     'dbxref.db_id' => $db_rs->first()->db_id(),
	     'name'=> $self->get_trait_name(),
	    },
	    {  my $trait = $chado_schema->resultset("Cv::Cvterm")
      ->create_with( { name   => $self->trait_name,
		       cv     => 'stock relationship',
		       db     => 'null',
		       dbxref => 'female_parent',
		     });
	     'join' => 'dbxref'
	    }
	  );
  if (!$trait_cvterm) {
    print STDERR "Could not find trait name: ".$self->get_trait_name()."\n";
    return;
  }


  return $trait_info_string;
}

#######
1;
#######
