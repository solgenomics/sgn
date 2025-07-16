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
	my $trait_name = shift;
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
    print STDERR "Could not find trait name: ".$trait_name."\n";
    return;
  }

  #get cvtermprops
  my $cvtermprops = $trait_cvterm->search_related('cvtermprops');

	# add full name in detail field, plus scale info if it's available
	my $trait_details = $trait_name;
	my $trait_def = $trait_cvterm->definition();
	$trait_def =~ s/([^\.]*\.\s{1})//;
	if ($trait_def =~ /=/) { $trait_details .= "\n" . $trait_def; }
	#print STDERR "trait details = $trait_details\n";

  my $cvterms = $self->_get_cvterms();

  my %trait_props;
  #set default values
  $trait_props{'trait_format'}='numeric';
  $trait_props{'trait_default_value'}='';
  $trait_props{'trait_minimum'}='';
  $trait_props{'trait_maximum'}='';
  $trait_props{'trait_details'}=$trait_details;
  $trait_props{'trait_categories'}='';


	print STDERR "trait name = $trait_name\n";
	# change from default numeric based on trait name
	if ($trait_name =~ m/percent/) {
		$trait_props{'trait_format'}='percent';
		$trait_props{'trait_minimum'}='0';
		$trait_props{'trait_maximum'}='100';
		$trait_props{'trait_default_value'}='50';
	}
#	elsif ($trait_name =~ m/counting/) {
#		$trait_props{'trait_format'}='counter';
#	}
	elsif ($trait_name =~ m/image/) {
		$trait_props{'trait_format'}='photo';
	}
	elsif ($trait_name =~ m/([0-9])-([0-9]+)/) {
		print STDERR "matched categorical trait with scale $1 to $2\n";

		if (($2-$1) >= 12) { #leave categorical traits as numeric if they exceed fieldbook's max of 12 categories
			$trait_props{'trait_minimum'}=$1;
			$trait_props{'trait_maximum'}=$2;
		} else {
			$trait_props{'trait_format'}='categorical';
			my $categories;
			foreach (my $i=$1; $i < $2; $i++ ) {
				$categories .= $i . "/";
			}
			$categories .= $2;
			print STDERR "categories = $categories\n";
			$trait_props{'trait_categories'}= $categories;
		}
	}

	# change from default numeric based on properties stored in the database
	# first pass to update all props as was done previously
	foreach my $property_name (keys %{$cvterms}) {
		my $prop_cvterm = $cvterms->{$property_name};
		my $prop = $cvtermprops->find({ 'type_id' => $prop_cvterm->cvterm_id() });
		if ($prop && $prop->value()) {
			$trait_props{$property_name} = $prop->value();
		}
	}

	# updates for Breeding Insight
	my $prop_cvterm = $cvterms->{'trait_format'};
	my $prop = $cvtermprops->find({ 'type_id' => $prop_cvterm->cvterm_id() });
	if ($prop && $prop->value()) {
		$trait_props{'trait_format'} = _convert_brapi_datatype($prop->value());
	}

	# update trait_details & trait_categories if not already updated
	if ($trait_name !~ m/([0-9])-([0-9]+)/) {
		my $prop_cvterm = $cvterms->{'trait_categories'};
		my $prop = $cvtermprops->find({ 'type_id' => $prop_cvterm->cvterm_id() });
		if ($prop && $prop->value()) {
			my $categories_str = "";
			my $trait_details_str = "";

			my @trait_categories = split /\//, $prop->value();
			foreach my $category (@trait_categories) {
				if ($trait_details_str ne "") {
					$trait_details_str = $trait_details_str . "/";
				}
				if ($categories_str ne "") {
					$categories_str = $categories_str . "/";
				}
				my @split_value = split('=', $category);
				if (scalar(@split_value) == 1) {
					$trait_details_str = $trait_details_str . $split_value[0];
				}
				elsif (scalar(@split_value) > 1) {
					$trait_details_str = $trait_details_str . $category;
				}
				$categories_str = $categories_str . $split_value[0];
			}

			$trait_props{'trait_details'} = $trait_details_str;
			$trait_props{'trait_categories'} = $categories_str;
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
		    });
  }

  return \%cvterms;

}

# If datatype is BrAPI type as stored through BrAPI convert, otherwise pass through value
sub _convert_brapi_datatype {
	my $datatype = shift;

	if ($datatype eq "Nominal" || $datatype eq "Ordinal") {
		return "categorical";
	}
	if ($datatype eq "Date") {
		return "date";
	}
	if ($datatype eq "Numerical" || $datatype eq "Duration") {
		return "numeric";
	}
	if ($datatype eq "Code" || $datatype eq "Text") {
		return "text";
	}
	return $datatype;
}

#######
1;
#######
