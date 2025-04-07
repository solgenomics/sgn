=head1 NAME

ToolCompatibility.pm - a MooseX::Runnable module for running tool compatibility calculations. Used as a background script. 

=head1 SYNOPSIS

mx-run ToolCompatibility --dataset_id <id> --genotyping_protocol [default genotyping protocol] --dbhost [host] --dbname [dbname] --user [dbuser] --password [dbpassword]

=head1 OPTIONS

=over 6

=item --dataset_id

The ID of the dataset, as stored in the database

=item --genotyping_protocol

The default genotyping protocol of this site. Used only if no genotyping protocol available in dataset.

=item --dbhost

The database hostname

=item --dbname

Database name

=item --user

Database user

=item --password

Database password

=back

=head1 AUTHOR

Ryan Preble <rsp98@cornell.edu>

=cut

package CXGN::Dataset::ToolCompatibility;

use Moose;
use CXGN::DB::InsertDBH;
use Bio::Chado::Schema;
use CXGN::People::Schema;
use CXGN::Dataset;

use strict;
use warnings;

with 'MooseX::Getopt';
with 'MooseX::Runnable';

has 'dataset_id' => (isa => 'Int', is => 'ro', required => 1);

has 'genotyping_protocol' => (isa => 'Str', is => 'ro', required => 1);

has 'dbhost' => (isa => 'Str', is => 'ro', required => 1);

has 'dbname' => (isa => 'Str', is => 'ro', required => 1);

has 'user' => (isa => 'Str', is => 'ro', required => 1);

has 'password' => (isa => 'Str', is => 'ro');

sub run {
    my $self = shift;

    my $dataset_id = $self->dataset_id;
    print STDERR "Starting tool compatibility check for ID $dataset_id.\n";
    my $genotyping_protocol = $self->genotyping_protocol;
    my $dbhost = $self->dbhost;
    my $dbname = $self->dbname;
    my $user = $self->user;
    my $password = $self->password;

    print STDERR "Connecting to DB.x\n";

    eval {
        my $dbh = CXGN::DB::Connection->new(
            { 
                dbhost=>$dbhost,
                dbname=>$dbname,
                dbuser=>$user,
                #dbpass=>$password,
                dbargs => {
                    AutoCommit => 0,
                    RaiseError => 1
                }
            }
        );
    }
    if ($@) {
        die "Error connecting to DB $@\n";
    }
    

    my $people_schema = CXGN::People::Schema->connect(  sub { $dbh->get_actual_dbh() } );
    my $bcs_schema= Bio::Chado::Schema->connect(  sub { $dbh->get_actual_dbh() } );

    my $dataset = CXGN::Dataset->new({
        people_schema => $people_schema,
        schema => $bcs_schema,
        sp_dataset_id => $dataset_id
    }); 

    eval {
        $dataset->update_tool_compatibility($genotyping_protocol);
    };
    if ($@) {
        $dbh->rollback();
        die "Tool compatibility failed.$@\n";
    }

    $dbh->commit();
    $dbh->disconnect();

    1; 
}

1; 