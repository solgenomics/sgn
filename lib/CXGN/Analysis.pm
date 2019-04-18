
package CXGN::Analysis;

use Moose;

BEGIN { extends 'CXGN::Trial' };

has 'dataset_name' => (is => 'rw', isa => 'Str');

has 'dataset_info' => (is => 'rw', isa => 'ArrayRef');

has 'accessions' => (is => 'rw', isa => 'ArrayRef');

has 'data_hash' => (is => 'rw', isa => 'HashRef');

has ' 
