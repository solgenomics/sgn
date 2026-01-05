=head1 NAME

CXGN::File - a class to do functions with archived files

=head1 DESCRIPTION

CXGN::File is a class for managing the behaviors of archived files. Archived files are stored in the database with a unique ID 
and a file path. Not to be confused with CXGN::UploadFile, which is used when saving a file for the first time. 

=head1 SYNOPSIS

my $file = CXGN::File->new({
    file_id => $file_id
});

my $file_type = $file->type();

$file->type("multi_trial_upload");

$file->store();

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut 