
package CXGN::Trait;

use Moose;
use Data::Dumper;
use Try::Tiny;
use List::Util qw(max);
use JSON;
use CXGN::Onto;
use CXGN::BrAPI::v2::ExternalReferences;
use CXGN::BrAPI::v2::Methods;
use CXGN::BrAPI::v2::Scales;
use CXGN::BrAPI::Exceptions::ConflictException;
use CXGN::BrAPI::Exceptions::ServerException;
use CXGN::List::Transform;

## to do: add concept of trait short name; provide alternate constructors for term, shortname, and synonyms etc.

has 'bcs_schema' => ( isa => 'Bio::Chado::Schema',
		  is => 'rw',
		  required => 1,
    );

has 'cvterm_id' => (isa => 'Maybe[Int]',
		    is => 'rw',
		    #required => 1,
    );

has 'cvterm' => ( isa => 'Bio::Chado::Schema::Result::Cv::Cvterm',
		  is => 'rw');


has 'name' => ( isa => 'Str',
		is => 'rw',
		lazy => 1,
		default => sub {
		    my $self = shift;
		    return $self->cvterm->name();
		},

    );

has 'display_name' => (isa => 'Str',
		       is => 'ro',
		       lazy => 1,
		       default => sub {
			   my $self = shift;
			   my $db = $self->db();
			   my $name = $self->name();
			   my $accession = $self->accession();
			   #print STDERR $db." ".$name." ".$accession."\n";
			   if ($db && $name && $accession ) {
			       return $name ."|".$db.":".$accession;
			   }
			   return "";
		       }
    );

has 'accession' => (isa => 'Str',
		    is => 'rw',
		    lazy => 1,
		    default => sub {
			my $self = shift;
			my $rs = $self->bcs_schema()->resultset("Cv::Cvterm")
			    -> search( { cvterm_id => $self->cvterm_id() })
			    -> search_related("dbxref");
			if ($rs->count() ==1) {
			    my $accession = $rs->first()->get_column("accession");
			    return $accession;
			}
			return "";
		    }

    );

has 'term' => (isa => 'Str',
	       is => 'ro',
	       lazy => 1,
	       default => sub {
		   my $self = shift;
		   my $accession = $self->accession();
		   my $db = $self->db();
		   if ($accession && $db) {
		       return "$db:$accession";
		   }
		   return "";
	       }
    );

has 'db'   => ( isa => 'Str',
		is => 'rw',
		lazy => 1,
		default => sub {
		    my $self = shift;
		    my $rs = $self->bcs_schema()->resultset("Cv::Cvterm")->search( { cvterm_id => $self->cvterm_id()})->search_related("dbxref")->search_related("db");
		    if ($rs->count() == 1) {
			my $db_name =  $rs->first()->get_column("name");
			#print STDERR "DBNAME = $db_name\n";
			return $db_name;
		    }
		    return "";

		}
    );

has 'db_id'   => (
	isa => 'Int',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		if ($self->cvterm){
			my $rs = $self->cvterm->search_related("dbxref");
			if ($rs->count() == 1) {
				my $db_id =  $rs->first()->get_column("db_id");
				#print STDERR "DBID = $db_id\n";
				return $db_id;
			}
		}
		return "";
	}
);

has 'dbxref_id' => (
	isa => 'Int',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		if ($self->cvterm){
			my $rs = $self->cvterm->search_related("dbxref");
			if ($rs->count() == 1) {
				my $dbxref_id =  $rs->first()->get_column("dbxref_id");
				return $dbxref_id;
			}
		}
		return "";
	}
);

has 'definition' => (isa => 'Maybe[Str]',
		     is => 'rw',
		     lazy => 1,
		     default => sub {
			 my $self = shift;
			 return $self->cvterm->definition();
		     },

    );

has 'entity' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_entity' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	},
);

has 'attribute' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_attribute' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	},
);

has 'format' => (isa => 'Str',
		 is => 'ro',
		 lazy => 1,
		 default => sub {
		     my $self = shift;

		     my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			 {
			     cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_format'
			 },
			 { join => 'type'}
			 );

		     if ($row) {
			 return $row->value();
		     }
		     return "";
		 }
    );

has 'default_value' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_default_value' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return undef;
	}
);

has 'minimum' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_minimum' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return undef;
	}
);

has 'maximum' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_maximum' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return undef;
	}
);

has 'categories' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_categories' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return undef;
	}
);

has 'category_details' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_details' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return undef;
	}
);

has 'repeat_type' => (
	isa => 'Maybe[Str]',
	is => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{ cvterm_id => $self->cvterm_id(), 'type.name' => 'trait_repeat_type' },
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return undef;
	}
);

has 'associated_plots' => ( isa => 'Str',
			    is => 'ro',
			    lazy => 1,
			    default => sub { "not yet implemented" }
    );

has 'associated_accessions' =>  ( isa => 'Str',
				  is => 'ro',
				  lazy => 1,
				  default => sub { "not yet implemented" }
    );

has 'uri' => (isa => 'Str',
	is            => 'ro',
	lazy          => 1,
	default => sub {
		my $self = shift;
		my $row = $self->bcs_schema()->resultset("Cv::Cvtermprop")->find(
			{cvterm_id => $self->cvterm_id(), 'type.name' => 'uri'},
			{ join => 'type'}
		);

		if ($row) {
			return $row->value();
		}
		return "";
	}
);

has 'ontology_id' => (
	isa => 'Maybe[Int]',
	is => 'rw',
);

has 'synonyms' => (
	isa => 'Maybe[ArrayRef[Str]]',
	is  => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		my @synonyms = $self -> _fetch_synonyms();
		return [@synonyms];
	}
);

has 'external_references' => (
	isa => 'Maybe[CXGN::BrAPI::v2::ExternalReferences]',
	is  => 'rw',
);

has 'method' => (
	isa => 'Maybe[CXGN::BrAPI::v2::Methods]',
	is  => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		if (defined($self->cvterm_id)) {
			return CXGN::BrAPI::v2::Methods->new({
				bcs_schema => $self->bcs_schema,
				cvterm_id => $self->cvterm_id
			});
		} else { return;}
	}
);

has 'scale' => (
	isa => 'Maybe[CXGN::BrAPI::v2::Scales]',
	is  => 'rw',
	lazy => 1,
	default => sub {
		my $self = shift;
		if (defined($self->cvterm_id)) {
			return CXGN::BrAPI::v2::Scales->new({
				bcs_schema => $self->bcs_schema,
				cvterm_id => $self->cvterm_id
			});
		} else {return;}
	}
);

has 'active' => (
	isa => 'Bool',
	is  => 'rw'
);

has 'additional_info' => (
	is  => 'rw',
	isa => 'Maybe[HashRef]'
);

has 'cv_id' => (
	isa => 'Int',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $cv_id = $self->bcs_schema->resultset("Cv::Cv")->find(
			{
				name => 'trait_property'
			},
			{ key => 'cv_c1' }
		)->get_column('cv_id');
		return $cv_id;
	}
);

has 'trait_entity_id' => (
	isa => 'Int',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $trait_entity_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
			{
				name        => 'trait_entity',
				cv_id       => $self->cv_id,
				is_obsolete => 0
			},
			{ key => 'cvterm_c1' }
		)->get_column('cvterm_id');
		return $trait_entity_id;
	}
);

has 'trait_attribute_id' => (
	isa => 'Int',
	is => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $trait_attribute_id = $self->bcs_schema->resultset("Cv::Cvterm")->find(
			{
				name        => 'trait_attribute',
				cv_id       => $self->cv_id,
				is_obsolete => 0
			},
			{ key => 'cvterm_c1' }
		)->get_column('cvterm_id');
		return $trait_attribute_id;
	}
);

sub BUILD {
    #print STDERR "BUILDING...\n";
    my $self = shift;
    my $cvterm;

    if ($self->cvterm_id){
		# TODO: Throw a good error if cvterm can't be found
        $cvterm = $self->bcs_schema()->resultset("Cv::Cvterm")->find( { cvterm_id => $self->cvterm_id });
        $self->cvterm($cvterm);
		$self->active($cvterm->is_obsolete == 0);
    }
    if (defined $cvterm) {
        $self->name($self->name || $cvterm->name );
    }

    return $self;
}


sub store {
    my $self = shift;
    my $schema = $self->bcs_schema();
	my $error;

	# new variable
    my $name = _trim($self->name());
	my $description = $self->definition();
	my $ontology_id = $self->ontology_id(); # passed in value not used currently, uses config
	my $synonyms = $self->synonyms();
	my $active = $self->active();
	my $additional_info = $self->additional_info();
	my $trait_entity = $self->entity();
	my $trait_attribute = $self->attribute();


	# get cv_id from sgn_local.conf
	my $context = SGN::Context->new;
	my $cv_name = $context->get_conf('trait_ontology_cv_name');
	my $cvterm_name = $context->get_conf('trait_ontology_cvterm_name');
	my $ontology_name = $context->get_conf('trait_ontology_db_name'); #this is the only config key that actually gets used elsewhere

	# Get trait attributes cvterm ids
	my $trait_entity_id = $self->trait_entity_id;
	my $trait_attribute_id = $self->trait_attribute_id;

	# get cv_id for cv_name
	my $cv = $schema->resultset("Cv::Cv")->find(
		{
			name => $cv_name
		},
		{ key => 'cv_c1' }
	);
	my $cv_id = $cv->get_column('cv_id');

	# get cvterm_id for cvterm_name
	my $cvterm = $schema->resultset("Cv::Cvterm")->find(
		{
			name        => $cvterm_name,
			cv_id       => $cv_id,
			is_obsolete => 0
		},
		{ key => 'cvterm_c1' }
	);

	my $root_id = $cvterm->get_column('cvterm_id');

	# check to see if specified ontology exists
	my $db = $schema->resultset("General::Db")->find(
		{
			name => $ontology_name
		},
		{ key => 'db_c1' }
	);

	if (!defined($db)) {
		CXGN::BrAPI::Exceptions::ServerException->throw({message => "Error: Unable to create trait, ontology does not exist"});
	}

	$ontology_id = $db->get_column('db_id');

	# check to see if cvterm name already exists and don't attempt if so
	my $cvterm_exists = $schema->resultset("Cv::Cvterm")->find(
		{
			name        => $name,
			cv_id       => $cv_id,
			is_obsolete => 0
		},
		{ key => 'cvterm_c1' }
	);

	if (defined($cvterm_exists)) {
		CXGN::BrAPI::Exceptions::ConflictException->throw({message => "Variable with that name already exists"});
	}

	# lookup last numeric accession number in ontology if one exists so we can increment off that
	my $q = "select accession from dbxref where db_id=".$ontology_id." and accession ~ ".q('^\d+$')." order by accession desc limit 1;";
	my $sth = $self->bcs_schema->storage->dbh->prepare($q);
	$sth->execute();
	my ($accession) = $sth->fetchrow_array();

	if (!defined($accession)) {
		$accession = '0000001';
	} else {
		$accession++;
	}

	# get cvterm_id for VARIABLE_OF. Needs to be stored with cv_id = 'relationship'
    my $relationship_cv = $schema->resultset("Cv::Cvt")->find( { name => 'relationship'});
    my $rel_cv_id;
    if ($relationship_cv) {
        $rel_cv_id = $relationship_cv->cv_id ;
    } else {
        print STDERR "relationship ontology is not found in the database\n";
    }
	my $variable_of_cvterm = $schema->resultset("Cv::Cvterm")->find(
		{
			name        => 'VARIABLE_OF',
			cv_id       => $rel_cv_id,
			is_obsolete => 0
		},
		{ key => 'cvterm_c1' }
	);

	my $variable_of_id = $variable_of_cvterm->get_column('cvterm_id');

	my $new_term;

	# setup transaction for rollbacks in case of error
	my $coderef = sub {

		# add trait info to dbxref
		my $new_term_dbxref = $schema->resultset("General::Dbxref")->create(
			{ db_id       => $ontology_id,
				accession => $accession,
				version   => '1',
			},
			{ key => 'dbxref_c1' },
		);

		# add trait info to cvterm
		$new_term = $schema->resultset("Cv::Cvterm")->create(
			{   cv_id         => $cv_id,
				name        => $name,
				definition  => $description,
				dbxref_id   => $new_term_dbxref->dbxref_id(),
				is_obsolete => $active ? 0 : 1
            });

		# set cvtermrelationship VARIABLE_OF to put terms under ontology
		# add cvterm_relationship entry linking term to ontology root
		my $relationship = $schema->resultset("Cv::CvtermRelationship")->create(
			{   type_id      => $variable_of_id,
				subject_id => $new_term->get_column('cvterm_id'),
				object_id  => $root_id
			});

		# add synonyms
		foreach my $synonym (@{$synonyms}) {
			$new_term->add_synonym($synonym);
		}

		# Add trait entity
		if ($trait_entity) {
			my $prop_entity = $schema->resultset("Cv::Cvtermprop")->create(
				{
					cvterm_id => $new_term->get_column('cvterm_id'),
					type_id   => $trait_entity_id,
					value     => $trait_entity,
					rank      => 0
				}
			);
		}


		# Add trait attribute
		if ($trait_attribute) {
			my $prop_attribute = $schema->resultset("Cv::Cvtermprop")->create(
				{
					cvterm_id => $new_term->get_column('cvterm_id'),
					type_id   => $trait_attribute_id,
					value     => $trait_attribute,
					rank      => 0
				}
			);
		}

		# Save additional info
		my $rank = 0;
		my $additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cvterm_additional_info', 'trait_property')->cvterm_id();
		if (defined $additional_info) {
			my $prop_id = $schema->resultset("Cv::Cvtermprop")->create(
				{
					cvterm_id => $new_term->get_column('cvterm_id'),
					type_id   => $additional_info_type_id,
					value     => encode_json $additional_info,
					rank      => $rank
				}
			);
		}

		# save scale properties
		$self->scale->{cvterm_id} = $new_term->cvterm_id;
		$self->scale->store();
		$self->method->{cvterm_id} = $new_term->cvterm_id;
		$self->method->store();
		if ($self->external_references) {
			$self->external_references->{id} = $new_term->cvterm_id;
			my $result = $self->external_references->store();
			$self->external_references->{id} = [$new_term->cvterm_id];
		}

	};

	$self->bcs_schema()->txn_do($coderef);

	$self->cvterm_id($new_term->get_column('cvterm_id'));
	$self->cvterm($new_term);

	return $self;
}

sub update {

	my $self = shift;
	my $schema = $self->bcs_schema();

	# new variable
	my $name = _trim($self->name());
	my $description = $self->definition();
	my $entity = $self->entity();
	my $attribute = $self->attribute();
	my $active = $self->active();
	my $synonyms = $self->synonyms();
	my $cvterm_id = $self->cvterm_id();
	my $additional_info = $self->additional_info();

	my $trait_entity_id = $self->trait_entity_id();
	my $trait_attribute_id = $self->trait_attribute_id();

	$self->bcs_schema()->txn_do(sub {

		# Update the variable
		$self->cvterm->update({
			name        => $name,
			definition  => $description,
			is_obsolete => $active ? 0 : 1
		});

		# Remove old synonyms
		$self->delete_existing_synonyms();

		# Add new synonyms
		foreach my $synonym (@{$synonyms}) {
			$self->cvterm->add_synonym($synonym);
		}

		# Update trait entity
		$schema->resultset("Cv::Cvtermprop")->search(
			{
				cvterm_id => $self->cvterm_id,
				type_id   => $trait_entity_id
			}
		)->delete;
		if ($entity) {
			$schema->resultset("Cv::Cvtermprop")->create(
				{
					cvterm_id => $self->cvterm_id,
					type_id   => $trait_entity_id,
					value     => $entity,
					rank      => 0
				}
			);
		}

		# Update trait attribute
		$schema->resultset("Cv::Cvtermprop")->search(
			{
				cvterm_id => $self->cvterm_id,
				type_id   => $trait_attribute_id
			}
		)->delete;
		if ($attribute) {
			$schema->resultset("Cv::Cvtermprop")->create(
				{
					cvterm_id => $self->cvterm_id,
					type_id   => $trait_attribute_id,
					value     => $attribute,
					rank      => 0
				}
			);
		}

		# Delete old additional info
		my $additional_info_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'cvterm_additional_info', 'trait_property')->cvterm_id();
		$schema->resultset("Cv::Cvtermprop")->search(
			{
				cvterm_id => $self->cvterm_id,
				type_id   => $additional_info_type_id
			}
		)->delete;

		# Add new additional info
		my $rank = 0;
		if (defined $additional_info) {
			my $prop_id = $schema->resultset("Cv::Cvtermprop")->create(
				{
					cvterm_id => $self->cvterm_id,
					type_id   => $additional_info_type_id,
					value     => encode_json $additional_info,
					rank      => $rank
				}
			);
		}

		# update scale properties
		$self->scale->{cvterm_id} = $cvterm_id;
		$self->scale->store();
		$self->method->{cvterm_id} = $cvterm_id;
		$self->method->store();
		if ($self->external_references) {
			$self->external_references->{id} = $cvterm_id;
			$self->external_references->store();
			$self->external_references->{id} = [ $cvterm_id ];
		}
	});

	# Get the variable
	#TODO: Query the variable
	return $self;
}

sub delete_existing_synonyms {
	my $self = shift;
	my $schema = $self->bcs_schema();
	$schema->resultset("Cv::Cvtermsynonym")->search(
		{cvterm_id => $self->cvterm_id}
	)->delete;
}

sub interactive_store {
	my $self = shift;
    my $parent_term = shift;

    my $schema = $self->bcs_schema();

	my $parent_id;

    my $name = $self->name() || die "No name found.\n";
    my $definition = $self->definition() || die "No definition found.\n";
    my $format = $self->format() || die "No format found.\n";
    my $default_value = $self->default_value() ne "" ? $self->default_value() : undef;
    my $minimum = $self->minimum() ne "" ? $self->minimum() : undef;
    my $maximum = $self->maximum() ne "" ? $self->maximum() : undef;
    my $categories = $self->categories() ne "" ? $self->categories() : undef;
	my $repeat_type = $self->repeat_type() ne "" ? $self->repeat_type () : undef;
	my $category_details = $self->category_details() ne "" ? $self->category_details() : undef;

    my $trait_property_cv_id = $schema->resultset("Cv::Cv")->find({name => 'trait_property'})->cv_id();

    my $minimum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_minimum'
    })->cvterm_id();

    my $maximum_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_maximum'
    })->cvterm_id();

    my $format_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_format'
    })->cvterm_id();

    my $default_value_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_default_value'
    })->cvterm_id();

    my $categories_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_categories'
    })->cvterm_id();

	my $repeat_type_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_repeat_type'
    })->cvterm_id();

	my $category_details_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        cv_id => $trait_property_cv_id,
        name => 'trait_details'
    })->cvterm_id();

    my %cvtermprop_hash = (
        "$format_cvterm_id" => $format,
        "$default_value_cvterm_id" => $default_value,
        "$minimum_cvterm_id" => $minimum,
        "$maximum_cvterm_id" => $maximum,
        "$categories_cvterm_id" => $categories,
        "$repeat_type_cvterm_id" => $repeat_type,
        "$category_details_cvterm_id" => $category_details
    );

	my $trait_ontology_cvterm_id = $schema->resultset("Cv::Cvterm")->find({
        name => 'trait_ontology'
    })->cvterm_id();
	my $trait_cv_id = $schema->resultset("Cv::Cvprop")->find({
		type_id => $trait_ontology_cvterm_id
	})->cv_id();
	my $trait_ontology = $schema->resultset("Cv::Cv")->find({
		cv_id => $trait_cv_id
	})->name();

	my $get_db_from_cv_sql = "SELECT DISTINCT(db.name) FROM cvterm 
	JOIN dbxref USING (dbxref_id)
	JOIN db USING (db_id)
	WHERE cv_id=?";

	my $h = $schema->storage->dbh->prepare($get_db_from_cv_sql);
    $h->execute($trait_cv_id);

	my $db_name = $h->fetchrow_array();

	if ($parent_term) {
		my $lt = CXGN::List::Transform->new();
    
		my $transform = $lt->transform($schema, "traits_2_trait_ids", [$parent_term]);

		if (@{$transform->{missing}}>0) { 
			die "Parent term $parent_term could not be found in the database.\n";
		}

		my @parent_id_list = @{$transform->{transform}};
		$parent_id = $parent_id_list[0];
	} else {
		my $ontology_obj = CXGN::Onto->new({
			schema => $schema
		});
		my @root_nodes = $ontology_obj->get_root_nodes('trait_ontology');

		my $root_term_name = $root_nodes[0]->[1] =~ s/\w+:\d+ //r;

		$parent_id = $schema->resultset("Cv::Cvterm")->find({
			name => $root_term_name,
			cv_id => $root_nodes[0]->[0]
		})->cvterm_id();
	}

    my $get_db_accessions_sql = "SELECT accession FROM dbxref JOIN db USING (db_id) WHERE db.name=?;";

    my $relationship_cv = $schema->resultset("Cv::Cv")->find({ name => 'relationship'});
    my $rel_cv_id;
    if ($relationship_cv) {
        $rel_cv_id = $relationship_cv->cv_id ;
    } else {
        die "No relationship ontology in DB.\n";
    }
    my $variable_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'VARIABLE_OF' , cv_id => $rel_cv_id });
    my $variable_of_id;
    if ($variable_relationship) {
        $variable_of_id = $variable_relationship->cvterm_id();
    }
    my $isa_relationship = $schema->resultset("Cv::Cvterm")->find({ name => 'is_a' , cv_id => $rel_cv_id });
    my $isa_id;
    if ($isa_relationship) {
        $isa_id = $isa_relationship->cvterm_id();
    }

    $h = $schema->storage->dbh->prepare($get_db_accessions_sql);
    $h->execute($db_name);

    my @accessions;

    while (my $accession = $h->fetchrow_array()) {
        push @accessions, int($accession =~ s/^0+//r);
    }

    my $accession_num = max(@accessions) + 1;
    my $zeroes = "0" x (7-length($accession_num));

    my $new_trait_id;
    my $new_trait;

    my $coderef = sub {
        $new_trait_id = $schema->resultset("Cv::Cvterm")->create_with({
            name => $name,
            cv => $trait_ontology,
            db => $db_name,
            dbxref => "$zeroes"."$accession_num"
        })->cvterm_id();

        if ($format eq "ontology") {
            $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                object_id => $parent_id,
                subject_id => $new_trait_id,
                type_id => $isa_id
            });
        } else {
            $schema->resultset("Cv::CvtermRelationship")->find_or_create({
                object_id => $parent_id,
                subject_id => $new_trait_id,
                type_id => $variable_of_id
            });
        }

        $new_trait = $schema->resultset("Cv::Cvterm")->find({
            cv_id => $trait_cv_id,
            cvterm_id => $new_trait_id,
            name => $name
        });
        $new_trait->definition($definition);
        $new_trait->update();

        foreach my $cvtermprop (keys(%cvtermprop_hash)) {
            if (defined($cvtermprop_hash{$cvtermprop})) {
                $schema->resultset("Cv::Cvtermprop")->create({
                    cvterm_id => $new_trait_id,
                    type_id => $cvtermprop,
                    value => $cvtermprop_hash{$cvtermprop},
                    rank => 0
                });
            }
        }
    };

    $schema->txn_do($coderef);

	$self->cvterm_id($new_trait_id);
	$self->dbxref_id($new_trait->dbxref_id);

    return $new_trait;
}

sub interactive_update {
	my $self = shift;
	my $schema = $self->bcs_schema();
	my $cvterm_id = $self->cvterm_id();
	my $definition = $self->definition();
	my $name = $self->name();

	my $coderef = sub {
		my $update_cvterm_sql = "UPDATE cvterm SET name = ? , definition = ? WHERE cvterm_id=?";

		my $h = $schema->storage->dbh->prepare($update_cvterm_sql);
		$h->execute($name, $definition, $cvterm_id);
	};

	$schema->txn_do($coderef);
}

sub delete {
	my $self = shift;

	my $schema = $self->bcs_schema;
	my $cvterm_id = $self->cvterm_id;
	my $name = $self->name;

	my $check_phenotypes_q = "SELECT COUNT(*) FROM phenotype WHERE cvalue_id=?";

	my $h = $schema->storage->dbh->prepare($check_phenotypes_q);
	$h->execute($cvterm_id);

	my $phenotype_count = $h->fetchrow_array();

	if ($phenotype_count > 0) {
		die "Cannot delete cvterm $name because it has associated phenotypes. Delete these phenotypes before attempting to delete the cvterm.\n";
	}

	if (!$self->db) {
		die "It appears this cvterm is not part of an ontology. Deleting it is likely unsafe.\n";
	}

	my $coderef = sub {
		$schema->resultset("Cv::Cvterm")->find({
			cvterm_id => $cvterm_id
		})->delete();

		$schema->resultset("General::Dbxref")->find({
			dbxref_id => $self->dbxref_id
		})->delete();
	};

	$schema->txn_do($coderef);

	return;
}

sub _fetch_synonyms {
	my $self = shift;
	my @synonyms = ();
	if (defined($self->cvterm)){
		my $synonym_rs = $self->cvterm->cvtermsynonyms;

		while ( my $s = $synonym_rs->next ) {
			push @synonyms, $s->synonym;
		}
	}
	my @sorted = sort { length $a <=> length $b } @synonyms;
	return @sorted;
}

# TODO: common utilities somewhere, used by Location also
sub _trim { #trim whitespace from both ends of a string
	my $s = shift;
	$s =~ s/^\s+|\s+$//g;
	return $s;
}

# gmod
sub numeric_id {
	my $id = shift;
	$id =~ s/.*\:(.*)$/$1/g;
	return $id;
}

sub get_active_string {
	my $self = shift;
	return $self->{active} ? 'active' : 'archived';
}


1;
