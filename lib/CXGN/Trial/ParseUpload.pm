package CXGN::Trial::ParseUpload;

use Moose;
use Data::Dumper;
use MooseX::FollowPBP;
use Moose::Util::TypeConstraints;

with 'MooseX::Object::Pluggable';


has 'chado_schema' => (
		       is       => 'ro',
		       isa      => 'DBIx::Class::Schema',
		       required => 1,
		      );

has 'filename' => (
		   is => 'ro',
		   isa => 'Str',
		   required => 1,
		  );

has 'parse_errors' => (
		       is => 'ro',
		       isa => 'HashRef',
		       writer => '_set_parse_errors',
		       reader => 'get_parse_errors',
		       predicate => 'has_parse_errors',
		      );

has '_parsed_data' => (
		       is => 'ro',
		       isa => 'HashRef',
		       writer => '_set_parsed_data',
		       predicate => '_has_parsed_data',
		      );

sub parse {
  my $self = shift;

  if (!$self->_validate_with_plugin()) {
		my $errors = $self->get_parse_errors();
    #print STDERR "\nCould not validate trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
  }

  print STDERR "Check 3.1: ".localtime();

  if (!$self->_parse_with_plugin()) {
		my $errors = $self->get_parse_errors();
    #print STDERR "\nCould not parse trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
  }

  print STDERR "Check 3.2: ".localtime();

  if (!$self->_has_parsed_data()) {
		my $errors = $self->get_parse_errors();
    #print STDERR "\nNo parsed data for trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
    return;
  } else {
    return $self->_parsed_data();
  }

  print STDERR "Check 3.3: ".localtime();

	my $errors = $self->get_parse_errors();
  #print STDERR "\nError parsing trial file: ".$self->get_filename()."\nError:".Dumper($errors)."\n";
  return;
}


1;
