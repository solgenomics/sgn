#!/usr/bin/env perl
package AddDesignReplicationStockprop;

use Moose;
use Bio::Chado::Schema;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::DesignReplication;
extends 'CXGN::Metadata::Dbpatch';

=head1 NAME

AddDesignReplicationStockprop - preserve recorded field design replication tags

=head1 DESCRIPTION

Creates design_replicate stock metadata and accession_occurrence_version project
metadata. Captures available legacy field replication tags without changing the
old replicate value, physical blocks or measurements. A NULL snapshot row records
missing information. Same-field descendants inherit the recorded plot group;
external study units retain their local metadata. Conflicting pooled parents
remain explicitly unknown. Existing snapshots are never overwritten on rerun.

This patch preserves available records, not a reconstructed original layout.
Occurrence normalization is a separately previewed, atomic correction operation.

=cut

has '+description' => (default => 'Preserve recorded design replication separately from field accession occurrence labels');
has '+prereq' => (default => sub {[]});

sub patch {
    my ($self)=@_;
    my $schema=Bio::Chado::Schema->connect(sub {$self->dbh->clone});
    $schema->txn_do(sub {
        $schema->resultset('Cv::Cvterm')->create_with({name=>'design_replicate',cv=>'stock_property',definition=>'Recorded replication tag of the declared design; independent of accession occurrence numbering. NULL explicitly records missing metadata.'});
        $schema->resultset('Cv::Cvterm')->create_with({name=>'accession_occurrence_version',cv=>'project_property',definition=>'Version 1 means the whole field layout has atomically normalized accession occurrence counters.'});
        my $field=SGN::Model::Cvterm->get_cvterm_row($schema,'field_layout','experiment_type')->cvterm_id;
        my $plot=SGN::Model::Cvterm->get_cvterm_row($schema,'plot','stock_type')->cvterm_id;
        my $trials=$schema->storage->dbh->selectcol_arrayref('SELECT DISTINCT nep.project_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) JOIN nd_experiment_stock nes USING(nd_experiment_id) JOIN stock s USING(stock_id) WHERE ne.type_id=? AND s.type_id=? ORDER BY nep.project_id',undef,$field,$plot);
        for my $trial (@$trials) {
            $schema->storage->dbh->selectrow_array('SELECT project_id FROM project WHERE project_id=? FOR UPDATE',undef,$trial);
            my $service=CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial});
            my $units=$service->load_units;
            my @plots=sort {$a<=>$b} keys %$units;
            my %initial=map {$_=>$units->{$_}{design_replicate}} @plots;
            my $children=$service->_children(\@plots);
            my %descendants;
            for my $parent (keys %$children) {
                $descendants{$_->{stock_id}}=$_ for @{$children->{$parent}{in_trial} || []};
            }
            my %root_ids=map {$_=>1} map {@{$_->{plot_parents}}} values %descendants;
            my $groups=CXGN::Trial::DesignReplication::read($schema,[keys %root_ids]);
            for my $id (keys %descendants) {
                my $child=$descendants{$id};
                my %tags=map {my $value=$groups->{$_}{value}; (defined($value) ? 'V'.$value:'N')=>1} @{$child->{plot_parents}};
                my $local=@{$child->{field_projects}}==1 && $child->{field_projects}[0]==$trial;
                for my $root (@{$child->{plot_parents}}) {
                    $local=0 if @{$groups->{$root}{field_projects}}!=1 || $groups->{$root}{field_projects}[0]!=$trial;
                }
                $initial{$id}=keys(%tags)==1 && $local ? $groups->{$child->{plot_parents}[0]}{value}:undef;
                warn "Field study $trial unit $id has ambiguous parent groups/layouts; recording unknown.\n" if keys(%tags)!=1 || !$local;
            }
            CXGN::Trial::DesignReplication::capture($schema,[sort {$a<=>$b} keys %initial],\%initial);
        }
    });
    print "Recorded design replication snapshots preserved; field occurrence counters unchanged.\n";
}

1;
