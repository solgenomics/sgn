
package CXGN::Analysis::Model;

use Moose;

has 'bcs_schema' => ( isa => 'Ref', is => 'rw' );

has 'people_schema' => ( isa => 'Ref', is => 'rw');

has 'name' => (isa => 'Str', is => 'rw');

has 'description' => (isa => 'Str', is => 'rw');

has 'model_data' => (isa => 'Int', is => 'rw'); # dataset_id

has 'category' => (isa => 'Str', is => 'rw'); # controlled vocabulary? YES... 'NIRS prediction', 'Mixed model', 'genomic prediction'

has 'file_based_storage' => (isa => 'boolean', is => 'rw');

has 'application_name' => ( isa => 'Str', is => 'rw');  # 

has 'application_version' => (isa => 'str', is => 'rw'); 

has 'model_file' => ( isa => 'Str', is => 'rw') ;  # .rds file

has 'model_blob' => (isa => 'Str', is => 'rw');

has 'sp_person_id' => (isa => 'Str', is => 'rw');

has 'is_public' => (isa => 'Int', is => 'rw');


sub BUILD {

}


sub store {

}


# class method

sub get_models_for_user {

}


sub get_models_public {

}




