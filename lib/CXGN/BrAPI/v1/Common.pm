package CXGN::BrAPI::v1::Common;

=head1 NAME
 CXGN::BrAPI::v1::Common - parent class for BrAPI subclasses.
=head1 DESCRIPTION
 Defines the following properties:
=over 4
=item bcs_schema
 A Bio::Chado::Schema object
=item metadata_schema
 A CXGN::Metadata::Schema object
=item phenome_schema
 A CXGN::Phenome::Schema object
=item people_schema
 A CXGN::People::Schema
=item page
 The page to be retrieved
=item page_size
 The current page_size
=item status
 Current BrAPI status information
=back
=head1 AUTHORS
 Nicolas Morales <nm529@cornell.edu>
 Lukas Mueller <lam87@cornell.edu>
=cut

 use Moose;

 has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1,
    );

 has 'metadata_schema' => (
    isa => 'CXGN::Metadata::Schema',
    is => 'rw',
    required => 1,
    );

 has 'phenome_schema' => (
    isa => 'CXGN::Phenome::Schema',
    is => 'rw',
    required => 1,
    );

 has 'people_schema' => (
    isa => 'CXGN::People::Schema',
    is => 'rw',
    required => 1,
    );

has 'context' => (
   is => 'rw',
   required => 1,
);

 has 'page_size' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
    );

 has 'page' => (
    isa => 'Int',
    is => 'rw',
    required => 1,
    );

 has 'status' => (
    isa => 'ArrayRef[Maybe[HashRef]]',
    is => 'rw',
    required => 1,
    );

 1;
