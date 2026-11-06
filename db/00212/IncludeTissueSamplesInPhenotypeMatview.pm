#!/usr/bin/env perl
package IncludeTissueSamplesInPhenotypeMatview;

use Moose;
use Bio::Chado::Schema;
use SGN::Model::Cvterm;
extends 'CXGN::Metadata::Dbpatch';

=head1 NAME

IncludeTissueSamplesInPhenotypeMatview - retain tissue observations in analytics

=head1 DESCRIPTION

The materialized phenotype table accepts tissue_sample as an observation level,
but its germplasm relationship predicate historically omitted tissue_sample_of.
This patch adds that existing relationship type without changing the remaining
query, column types, indexes, owner or grants. It rebuilds derived data in one
transaction; raw observations and stock relationships are never modified.

The rebuild takes an exclusive lock. Custom dependent objects are deliberately
not dropped with CASCADE: they require an explicit migration plan. Ambiguous
multiple-germplasm units can fail the existing unique-unit index and must be
reviewed rather than silently deduplicated. Repeated execution is a no-op.

=cut

has '+description' => (default=>'Include existing tissue_sample_of germplasm links in the materialized phenotype table');
has '+prereq' => (default=>sub {['UpdatePhenotypeJsonbTableMaterializedViewIntercrop']});

sub patch {
    my ($self)=@_;
    my $schema=Bio::Chado::Schema->connect(sub {$self->dbh->clone});
    my $dbh=$schema->storage->dbh;
    $schema->txn_do(sub {
        my $relation=$dbh->selectrow_hashref(q{
            SELECT c.oid,c.relkind,c.relowner AS owner_oid,pg_get_userbyid(c.relowner) AS owner,am.amname,
                   pg_get_viewdef(c.oid,true) AS definition,
                   obj_description(c.oid,'pg_class') AS comment,
                   c.reloptions,t.spcname AS tablespace
            FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            LEFT JOIN pg_tablespace t ON t.oid=c.reltablespace
            LEFT JOIN pg_am am ON am.oid=c.relam
            WHERE n.nspname='public' AND c.relname='materialized_phenotype_jsonb_table'
        });
        die "Run the materialized phenotype-table migrations first.\n" if !$relation || $relation->{relkind} ne 'm';
        my $tissue=SGN::Model::Cvterm->get_cvterm_row($schema,'tissue_sample_of','stock_relationship')->cvterm_id;
        my $definition=$relation->{definition};
        my $predicate=qr/\bstock_relationship\.type_id\s*=\s*ANY\s*\(ARRAY\[([\d,\s]+)\]\)/;
        my @matches=($definition =~ /$predicate/g);
        die "The materialized phenotype relationship predicate is customized; review it before adding tissue samples.\n" if @matches!=1;
        my @types=split /\s*,\s*/,$matches[0];
        s/^\s+|\s+$//g for @types;
        return if grep {$_==$tissue} @types;
        for my $name (qw(plot_of plant_of subplot_of analysis_of)) {
            my $expected=SGN::Model::Cvterm->get_cvterm_row($schema,$name,'stock_relationship')->cvterm_id;
            die "The materialized phenotype predicate lacks $name; review its migration history first.\n" if !grep {$_==$expected} @types;
        }
        push @types,$tissue;
        my $replacement='stock_relationship.type_id = ANY (ARRAY['.join(',',@types).'])';
        $definition =~ s/$predicate/$replacement/;
        $definition =~ s/;\s*$//;
        my $indexes=$dbh->selectall_arrayref(q{
            SELECT pg_get_indexdef(i.indexrelid),ic.relname,
                   obj_description(ic.oid,'pg_class'),CASE WHEN i.indisclustered THEN 1 ELSE 0 END
            FROM pg_index i JOIN pg_class ic ON ic.oid=i.indexrelid
            WHERE i.indrelid=? ORDER BY i.indexrelid
        },undef,$relation->{oid});
        my $columns=$dbh->selectall_arrayref(q{
            SELECT attname,attstattarget,col_description(attrelid,attnum),attoptions
            FROM pg_attribute WHERE attrelid=? AND attnum>0 AND NOT attisdropped ORDER BY attnum
        },undef,$relation->{oid});
        my ($security_labels)=$dbh->selectrow_array(q{
            SELECT count(*) FROM pg_seclabel WHERE classoid='pg_class'::regclass
            AND (objoid=? OR objoid IN (SELECT indexrelid FROM pg_index WHERE indrelid=?))
        },undef,$relation->{oid},$relation->{oid});
        die "Custom security labels require an explicit materialized-view migration plan.\n" if $security_labels;
        my $grants=_acl_rows($dbh,$relation->{oid});
        my $ordered=_ordered_grants($dbh,$grants,$relation->{owner_oid});
        my ($actor)=$dbh->selectrow_array('SELECT current_user');
        my %grantors=map {$_->[4]=>1} @$ordered;
        # Check permission to retain every original grantor BEFORE dropping a
        # derived object; an owner with insufficient role access fails safely.
        for my $grantor (sort keys %grantors) {
            $dbh->do('SET LOCAL ROLE '.$dbh->quote_identifier($grantor));
            $dbh->do('SET LOCAL ROLE '.$dbh->quote_identifier($actor));
        }
        my ($default_tablespace)=$dbh->selectrow_array('SHOW default_tablespace');
        $dbh->do("SET LOCAL default_tablespace = ''");
        my $view=$dbh->quote_identifier('public','materialized_phenotype_jsonb_table');
        my $storage=' USING '.$dbh->quote_identifier($relation->{amname});
        if ($relation->{reloptions} && @{$relation->{reloptions}}) {
            my @options;
            for my $option (@{$relation->{reloptions}}) {
                die "Unsupported materialized phenotype storage option: $option\n" if $option !~ /^[a-z_]+(?:\.[a-z_]+)?=(?:[a-z0-9_.-]+)$/;
                push @options,$option;
            }
            $storage.=' WITH ('.join(',',@options).')';
        }
        $storage.=' TABLESPACE '.$dbh->quote_identifier($relation->{tablespace}) if $relation->{tablespace};
        # No CASCADE: unexpected dependent objects fail this transaction safely.
        $dbh->do('DROP MATERIALIZED VIEW '.$view);
        $dbh->do('CREATE MATERIALIZED VIEW '.$view.$storage.' AS '.$definition.' WITH NO DATA');
        $dbh->do($_->[0]) for @$indexes;
        $dbh->do('ALTER MATERIALIZED VIEW '.$view.' OWNER TO '.$dbh->quote_identifier($relation->{owner}));
        # Remove creation-time default grants before restoring the original ACL.
        my ($new_oid)=$dbh->selectrow_array("SELECT 'public.materialized_phenotype_jsonb_table'::regclass::oid");
        my $created=_acl_rows($dbh,$new_oid);
        my %grantees=map {$_->[1]=>$_->[5]} @$created;
        for my $id (sort {$a<=>$b} keys %grantees) {
            my $quoted=$id==0 ? 'PUBLIC':$dbh->quote_identifier($grantees{$id});
            $dbh->do('REVOKE ALL PRIVILEGES ON TABLE '.$view.' FROM '.$quoted);
        }
        for my $grant (@$ordered) {
            my ($grantor,$grantee,$privilege,$grantable,$grantor_name,$grantee_name,$column_number,$column_name)=@$grant;
            die "Unsupported stored materialized phenotype privilege.\n" if $privilege !~ /^(?:SELECT|INSERT|UPDATE|DELETE|TRUNCATE|REFERENCES|TRIGGER|MAINTAIN)$/;
            my $quoted=$grantee==0 ? 'PUBLIC':$dbh->quote_identifier($grantee_name);
            my $scope=$column_number ? ' ('.$dbh->quote_identifier($column_name).')':'';
            $dbh->do('SET LOCAL ROLE '.$dbh->quote_identifier($grantor_name));
            $dbh->do('GRANT '.$privilege.$scope.' ON TABLE '.$view.' TO '.$quoted.($grantable ? ' WITH GRANT OPTION':''));
            $dbh->do('SET LOCAL ROLE '.$dbh->quote_identifier($actor));
        }
        die "Materialized phenotype permissions could not be restored exactly.\n"
            if _acl_signature(_acl_rows($dbh,$new_oid)) ne _acl_signature($grants);
        for my $column (@$columns) {
            my ($name,$statistics,$comment,$options)=@$column;
            my $target=$view.'.'.$dbh->quote_identifier($name);
            $dbh->do('COMMENT ON COLUMN '.$target.' IS '.$dbh->quote($comment)) if defined($comment);
            $dbh->do('ALTER MATERIALIZED VIEW '.$view.' ALTER COLUMN '.$dbh->quote_identifier($name).' SET STATISTICS '.int($statistics)) if $statistics!=-1;
            if ($options && @$options) {
                my @values;
                for my $option (@$options) {
                    my ($key,$value)=split /=/,$option,2;
                    die "Unsupported materialized phenotype column option.\n" if !defined($value) || $key !~ /^[a-z_]+$/;
                    push @values,$key.'='.$dbh->quote($value);
                }
                $dbh->do('ALTER MATERIALIZED VIEW '.$view.' ALTER COLUMN '.$dbh->quote_identifier($name).' SET ('.join(',',@values).')');
            }
        }
        for my $index (@$indexes) {
            my $name=$dbh->quote_identifier('public',$index->[1]);
            $dbh->do('COMMENT ON INDEX '.$name.' IS '.$dbh->quote($index->[2])) if defined($index->[2]);
            $dbh->do('ALTER MATERIALIZED VIEW '.$view.' CLUSTER ON '.$dbh->quote_identifier($index->[1])) if $index->[3];
        }
        $dbh->do('COMMENT ON MATERIALIZED VIEW '.$view.' IS '.$dbh->quote($relation->{comment})) if defined($relation->{comment});
        # REFRESH evaluates the definition with the restored view owner's rights.
        $dbh->do('REFRESH MATERIALIZED VIEW '.$view);
        $dbh->do("SELECT set_config('default_tablespace',?,true)",undef,$default_tablespace);
    });
    print "Materialized phenotype relationships include tissue samples; raw records preserved.\n";
}

# OIDs distinguish the PUBLIC pseudo-role from any quoted role name. Capture
# column ACLs as well as table ACLs; grantor chains must not be flattened.
sub _acl_rows {
    my ($dbh,$oid)=@_;
    return $dbh->selectall_arrayref(q{
        WITH entries AS (
            SELECT a.grantor,a.grantee,a.privilege_type,a.is_grantable,0 AS attnum,NULL::text AS attname
            FROM pg_class c CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a WHERE c.oid=?
          UNION ALL
            SELECT a.grantor,a.grantee,a.privilege_type,a.is_grantable,c.attnum,c.attname::text
            FROM pg_attribute c CROSS JOIN LATERAL aclexplode(c.attacl) a
            WHERE c.attrelid=? AND c.attnum>0 AND NOT c.attisdropped
        ) SELECT grantor,grantee,privilege_type,CASE WHEN is_grantable THEN 1 ELSE 0 END,
                 pg_get_userbyid(grantor),pg_get_userbyid(grantee),attnum,attname
          FROM entries ORDER BY attnum,grantor,grantee,privilege_type,is_grantable
    },undef,$oid,$oid);
}

sub _acl_signature {
    my ($rows)=@_;
    return join("\n",sort map {join('|',@{$_}[0,1,2,3,6])} @$rows);
}

sub _ordered_grants {
    my ($dbh,$rows,$owner)=@_;
    my (@ordered,%authority,%inherits);
    $authority{$owner}{$_->[2]}{0}=1 for @$rows;
    my @pending=@$rows;
    while (@pending) {
        my (@next,$progress);
        for my $grant (@pending) {
            my ($grantor,$grantee,$privilege,$grantable,undef,undef,$column)=@$grant;
            my $allowed=$grantor==$owner;
            for my $role (keys %authority) {
                next if !$authority{$role}{$privilege}{0} && !$authority{$role}{$privilege}{$column};
                my $key="$grantor/$role";
                $inherits{$key}=$dbh->selectrow_array("SELECT CASE WHEN pg_has_role(?::oid,?::oid,'USAGE') THEN 1 ELSE 0 END",undef,$grantor,$role) if !exists($inherits{$key});
                $allowed=1 if $inherits{$key};
            }
            if (!$allowed) {push @next,$grant;next}
            push @ordered,$grant;$progress=1;
            $authority{$grantee}{$privilege}{$column}=1 if $grantable && $grantee!=0;
        }
        die "The materialized phenotype grantor chain cannot be restored; review its permissions first.\n" if !$progress;
        @pending=@next;
    }
    return \@ordered;
}

1;
