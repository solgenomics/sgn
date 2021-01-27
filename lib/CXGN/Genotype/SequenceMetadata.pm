package CXGN::Genotype::SequenceMetadata;

=head1 NAME

CXGN::Genotype::SequenceMetadata - used to manage sequence metadata in the featureprop_json table

=head1 USAGE


=head1 DESCRIPTION


=head1 AUTHORS

David Waring <djw64@cornell.edu>

=cut


use strict;
use warnings;
use Moose;

use SGN::Context;


has 'shell_script_dir' => (
    isa => 'Str',
    is => 'ro',
    default => '/bin/sequence_metadata'
);

has 'bcs_schema' => (
    isa => 'Bio::Chado::Schema',
    is => 'rw',
    required => 1
);

has 'original_filepath' => (
    isa => 'Str|Undef',
    is => 'rw'
);

has 'verified_filepath' => (
    isa => 'Str|Undef',
    is => 'rw'
);



sub BUILD {
    my $self = shift;
}


sub verify {
    my $self = shift;
    my $input = shift;
    my $output = shift;
    my $c = SGN::Context->new;

    $self->original_filepath($input);
    $self->verified_filepath($output);

    my %results = (
        processed => 0,
        verified => 0,
        missing_features => ()
    );


    # PROCESS THE INPUT FILE
    # Remove comments
    # Sort by seqid and start
    # Save to output file
    my $script = $c->get_conf('basepath') . $self->shell_script_dir . "/preprocess_featureprop_json.sh";
    my $cmd = "bash " . $script . " \"" . $self->original_filepath . "\" \"" . $self->verified_filepath . "\"";
    my $rv = system($cmd);
    if ($rv == -1) {
        $results{'error'} = "Could not launch pre-processing script: $!";
    }
    elsif (my $s = $rv & 127) { 
        $results{'error'} = "Pre-processing script died from signal $s";
    }
    elsif (my $e = $rv >> 8)  { 
        $results{'error'} = "Pre-processing script exited with code $e"; 
    }
    

    # VERIFY THE FEATURES
    if ( $rv == 0 ) {
        $results{'processed'} = 1;
        
        my $script = $c->get_conf('basepath') . $self->shell_script_dir . "/get_unique_features.sh";
        my $cmd = "bash " . $script . " \"" . $self->verified_filepath . "\"";
        my @features = `$cmd`;

        my @missing = ();
        foreach my $feature ( @features ) {
            chomp($feature);
            my $query = "SELECT feature_id FROM public.feature WHERE uniquename=?" ;
            my $sth = $self->bcs_schema->storage->dbh()->prepare($query);
            $sth->execute($feature);
            my ($feature_id) = $sth->fetchrow_array();
            if ( $feature_id eq "" ) {
                push(@missing, $feature);
            }
        }
        my $missing_count = scalar(@missing);
        $results{'missing_features'} = \@missing;

        if ( $missing_count == 0 ) {
            $results{'verified'} = 1;
        }
    }


    return(\%results);
}


1;