=head1 NAME

CXGN::Jobs - a class to unify background job submission, storage, and reporting

=head1 DESCRIPTION

CXGN::Jobs is a central location where background jobs can be submitted through cxgn-corelibs/CXGN::Tools::Run. 
By routing all jobs through this module, all submitted jobs regardless of type can be stored in the sgn_people.sp_jobs 
and updated accordingly.

=head1 SYNOPSIS

my $job = CXGN::Jobs->new({
    people_schema => $people_schema
    schema => $bcs_schema
    args => $args
});
my $job_id = $job->submit_and_store();
...
my $job = CXGN::Jobs->new({
    people_schema => $people_schema
    schema => $bcs_schema
    sp_job_id => $job_id
});
$job->create_date();
$job->status();
$job->result_page();

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut 

package CXGN::Jobs;

use Moose;
use Moose::Util::TypeConstraints;
use Data::Dumper;
use JSON::Any;
use CXGN::Tools::Run;

=head1 ACCESSORS

=head2 people_schema()

accessor for CXGN::People::Schema database object

=cut

has 'people_schema' => (isa => 'CXGN::People::Schema',  is => 'rw', required => 1 );

=head2 schema()

accessor for Bio::Chado::Schema database object

=cut

has 'schema' => ( isa => "Bio::Chado::Schema", is => 'rw', required => 1 );

=head2 sp_job_id()

Database ID for submitted job

=cut 

has 'sp_job_id' => ( isa => 'Int', is => 'rw' );

=head2 sp_person_id()

User ID of the owner (submitter) of the job

=cut 

has 'sp_person_id' => ( isa => 'Maybe[Int]', is => 'rw' );

=head2 slurm_id()

ID of the running process, as managed by Slurm. Useful for checking job status using Slurm output

=cut

has 'slurm_id' => ( isa => 'Maybe[Int]', is => 'rw' );

=head2 create_timestamp()

Timestamp of job submission

=cut

has 'create_timestamp' => ( isa => 'Maybe[Str]', is => 'rw');

=head2 finish_timestamp()

Timestamp of job finishing, either successfully or on job failure

=cut

has 'finish_timestamp' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_finish_timestamp' );

=head2 status()

Current status of the job. May be stored in DB or may be gathered from Slurm (and then stored)

=cut 

has 'status' => ( isa => 'Maybe[Str]', is => 'rw');

=head2 submit_page()

The URL of the page from which this job was submitted

=cut

has 'submit_page' => (isa => 'Maybe[Str]', is => 'rw');

=head2 results_page()

The URL of the page for viewing results (if any)

=cut

has 'results_page' => ( isa => 'Maybe[Str]', is => 'rw', predicate => 'has_results_page');

=head2 args()

Hashref of arguments supplied to the job. Not necessarily needed for job creation, but 
essential for job submission. Must have keys for cmd and site basename. All other keys
can be customized for the job type. Stored in the DB as a JSONB. This is the place to 
include config for CXGN::Tools::Run.

Ex:

$args = {
    cmd => 'perl /bin/script.pl -a arg1 -b arg2',
    site => 'breedbase.org',
    config => '...',
    ...
};

=cut

has 'args' => ( isa => 'Maybe[Str]', is => 'rw' );