use strict;use warnings;use lib 't/lib';use lib 'db/00212';
use Test::More;use SGN::Test::Fixture;use SGN::Model::Cvterm;

# ADMIN-ONLY disposable fixture qualification. Roles, derived-view DDL, grants,
# comments and session-local settings all belong to one rollback transaction.
# The actual patch method is used; its schema constructor alone returns the
# existing rollback schema. The separate cold bootstrap tests real DBH cloning.
my $f=SGN::Test::Fixture->new;
BAIL_OUT('This test requires the isolated fixture configuration') if ($ENV{SGN_CONFIG_LOCAL_SUFFIX}//'') ne 'fixture';
# The ordinary fixture application user is deliberately not the migration admin.
# Use only the already-configured private task PostgreSQL environment here.
my $config=$f->config;
my $s=Bio::Chado::Schema->connect("dbi:Pg:dbname=$config->{dbname};host=$config->{dbhost}",$ENV{PGUSER},$ENV{PGPASSWORD});
my $dbh=$s->storage->dbh;
my($database,$actor)=$dbh->selectrow_array('SELECT current_database(),current_user');
BAIL_OUT("This test requires postgres on a fixture database (actual user=$actor database=$database)") if $actor ne 'postgres' || $database !~ /(?:fixture|^test_db_)/;
$s->storage->auto_savepoint(1);
my $prefix='audit_tissue_acl_'.$$;my $role1=$prefix.'_grantor';my $role2=$prefix.'_reader';my $dependent=$prefix.'_dependent';
my $view=$dbh->quote_identifier('public','materialized_phenotype_jsonb_table');
my $qrole1=$dbh->quote_identifier($role1);my $qrole2=$dbh->quote_identifier($role2);my $dep=$dbh->quote_identifier('public',$dependent);
sub snapshot {
 my $v=$dbh->selectrow_hashref(q{SELECT c.oid,c.relowner,pg_get_userbyid(c.relowner) AS owner,c.reloptions,c.reltablespace,am.amname,obj_description(c.oid,'pg_class') AS comment,pg_get_viewdef(c.oid,true) AS definition FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace LEFT JOIN pg_am am ON am.oid=c.relam WHERE n.nspname='public' AND c.relname='materialized_phenotype_jsonb_table'});
 my $oid=$v->{oid};
 $v->{indexes}=$dbh->selectall_arrayref(q{SELECT i.indexrelid,c.relname,pg_get_indexdef(i.indexrelid),c.relowner,c.reloptions,c.reltablespace,am.amname,obj_description(c.oid,'pg_class'),i.indisclustered FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid LEFT JOIN pg_am am ON am.oid=c.relam WHERE i.indrelid=? ORDER BY c.relname},undef,$oid);
 $v->{columns}=$dbh->selectall_arrayref(q{SELECT attnum,attname,attstattarget,attoptions,col_description(attrelid,attnum) FROM pg_attribute WHERE attrelid=? AND attnum>0 AND NOT attisdropped ORDER BY attnum},undef,$oid);
 $v->{acl}=$dbh->selectall_arrayref(q{SELECT 0::integer,a.grantee,a.grantor,a.privilege_type,a.is_grantable FROM pg_class c CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl,acldefault('r',c.relowner))) a WHERE c.oid=? UNION ALL SELECT p.attnum::integer,a.grantee,a.grantor,a.privilege_type,a.is_grantable FROM pg_attribute p CROSS JOIN LATERAL aclexplode(p.attacl) a WHERE p.attrelid=? AND p.attnum>0 AND NOT p.attisdropped ORDER BY 1,2,3,4,5},undef,$oid,$oid);
 return $v;
}
sub stable_metadata {
 my($v)=@_;my %copy=%$v;delete @copy{qw(oid definition)};
 $copy{indexes}=[map {[@$_[1..$#$_]]} @{$v->{indexes}}];return \%copy;
}
{package TissueACLContext;sub dbh {$_[0]{dbh}}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
sub patch {
 no warnings 'redefine';local *Bio::Chado::Schema::connect=sub {return $s};
 IncludeTissueSamplesInPhenotypeMatview::patch(bless({dbh=>$dbh},'TissueACLContext'));
}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ok=eval {
 require IncludeTissueSamplesInPhenotypeMatview;
 my $original=snapshot();is($original->{reltablespace},0,'fixture uses the original implicit database-default tablespace');
 die 'This test requires the fixture default tablespace' if $original->{reltablespace}!=0;
 my $definition=$original->{definition};my $tissue=SGN::Model::Cvterm->get_cvterm_row($s,'tissue_sample_of','stock_relationship')->cvterm_id;
 my $predicate=qr/\bstock_relationship\.type_id\s*=\s*ANY\s*\(ARRAY\[([\d,\s]+)\]\)/;
 my($types)=$definition=~/$predicate/;die 'Unsupported fixture view predicate' if !defined($types);
 my @legacy=grep {$_!=$tissue} split /\s*,\s*/,$types;
 for my $name(qw(plot_of plant_of subplot_of analysis_of)) {my$id=SGN::Model::Cvterm->get_cvterm_row($s,$name,'stock_relationship')->cvterm_id;die "Fixture predicate lacks $name" if !grep {$_==$id} @legacy}
 my $replacement='stock_relationship.type_id = ANY (ARRAY['.join(',',@legacy).'])';$definition=~s/$predicate/$replacement/;$definition=~s/;\s*$//;
 # The fixture's derived cache is rebuilt as the historical predicate only
 # inside this transaction. Raw observations/relationships are never changed.
 $dbh->do('DROP MATERIALIZED VIEW '.$view);
 my $options=$original->{reloptions} && @{$original->{reloptions}} ? ' WITH ('.join(',',@{$original->{reloptions}}).')':'';
 $dbh->do('CREATE MATERIALIZED VIEW '.$view.($original->{amname} ? ' USING '.$dbh->quote_identifier($original->{amname}):'').$options.' AS '.$definition.' WITH NO DATA');
 $dbh->do($_->[2]) for @{$original->{indexes}};
 $dbh->do('ALTER MATERIALIZED VIEW '.$view.' OWNER TO '.$dbh->quote_identifier($original->{owner}));
 $dbh->do('REFRESH MATERIALIZED VIEW '.$view);
 $dbh->do('CREATE ROLE '.$qrole1.' NOLOGIN');$dbh->do('CREATE ROLE '.$qrole2.' NOLOGIN');
 $dbh->do('GRANT USAGE ON SCHEMA public TO '.$qrole1.','.$qrole2);
 $dbh->do('GRANT SELECT ON TABLE '.$view.' TO PUBLIC');
 $dbh->do('GRANT SELECT ON TABLE '.$view.' TO '.$qrole1.' WITH GRANT OPTION');
 $dbh->do('GRANT SELECT (observationunit_stock_id) ON TABLE '.$view.' TO '.$qrole1.' WITH GRANT OPTION');
 $dbh->do('SET LOCAL ROLE '.$qrole1);
 $dbh->do('GRANT SELECT ON TABLE '.$view.' TO '.$qrole2);
 $dbh->do('GRANT SELECT (observationunit_stock_id) ON TABLE '.$view.' TO '.$qrole2);
 $dbh->do('RESET ROLE');
 my $column=$dbh->quote_identifier('observationunit_stock_id');
 $dbh->do('COMMENT ON MATERIALIZED VIEW '.$view.' IS '.$dbh->quote($prefix.'_view_comment'));
 $dbh->do('COMMENT ON COLUMN '.$view.'.'.$column.' IS '.$dbh->quote($prefix.'_column_comment'));
 $dbh->do('ALTER MATERIALIZED VIEW '.$view.' ALTER COLUMN '.$column.' SET STATISTICS 17');
 $dbh->do('ALTER MATERIALIZED VIEW '.$view.' ALTER COLUMN '.$column.' SET (n_distinct=7)');
 my $index=$dbh->selectrow_array('SELECT c.relname FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid WHERE i.indrelid=? AND i.indisunique ORDER BY c.relname LIMIT 1',undef,snapshot()->{oid});
 die 'Fixture lacks the unique-unit index' if !defined($index);
 $dbh->do('COMMENT ON INDEX '.$dbh->quote_identifier('public',$index).' IS '.$dbh->quote($prefix.'_index_comment'));
 $dbh->do('ALTER MATERIALIZED VIEW '.$view.' CLUSTER ON '.$dbh->quote_identifier($index));
 $dbh->do('CREATE VIEW '.$dep.' AS SELECT observationunit_stock_id FROM '.$view);
 my $before=snapshot();
 my($id1)=$dbh->selectrow_array('SELECT oid FROM pg_roles WHERE rolname=?',undef,$role1);my($id2)=$dbh->selectrow_array('SELECT oid FROM pg_roles WHERE rolname=?',undef,$role2);
 ok((grep {$_->[1]==0 && $_->[3] eq 'SELECT'} @{$before->{acl}}),'fixture has an actual PUBLIC OID0 grant');
 ok((grep {$_->[0]==0 && $_->[1]==$id2 && $_->[2]==$id1 && $_->[3] eq 'SELECT'} @{$before->{acl}}),'fixture has a real delegated table grant from its private grantor');
 ok((grep {$_->[0]>0 && $_->[1]==$id2 && $_->[2]==$id1 && $_->[3] eq 'SELECT'} @{$before->{acl}}),'fixture has a real delegated column grant');
 # Rebuild-time defaults deliberately add an OWNER-to-reader SELECT grant
 # absent from the saved delegated ACL. The patch must remove this extra grant.
 $dbh->do('ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT ON TABLES TO '.$qrole2);
 $dbh->do(q{SET LOCAL default_tablespace='pg_global'});
 $s->txn_begin;my $applied=eval {patch();1};my $error=$@;$s->txn_rollback;
 ok(!$applied,'ordinary dependent view prevents the migration without CASCADE');like($error,qr/depend|cannot drop/i,'dependency failure is explicit');
 is_deeply(snapshot(),$before,'failed migration preserves the old view OID, indexes, complete ACL and nondefault metadata');
 is($dbh->selectrow_array(q{SELECT current_setting('default_tablespace')}),'pg_global','failed attempt restores the original session-local tablespace setting');
 is($dbh->selectrow_array('SELECT current_user'),'postgres','failed attempt does not leak a delegated role');
 ok($dbh->selectrow_array('SELECT to_regclass(?) IS NOT NULL',undef,'public.'.$dependent),'private dependent view still exists after refused migration');
 $dbh->do('DROP VIEW '.$dep);
 patch();my $after=snapshot();
 isnt($after->{oid},$before->{oid},'the actual legacy materialized view was rebuilt after removing only the private dependency'); # codespell:ignore isnt
 is_deeply(stable_metadata($after),stable_metadata($before),'successful rebuild preserves grantors, column/table ACL, owner, indexes, access method, default tablespaces, comments, statistics, options and cluster hint');
 ok(($after->{definition}=~/\bstock_relationship\.type_id\s*=\s*ANY\s*\(ARRAY\[[\d,\s]*\b$tissue\b/),'rebuilt predicate includes the actual tissue relationship ID');
 is($dbh->selectrow_array(q{SELECT current_setting('default_tablespace')}),'pg_global','successful rebuild restores pg_global session value instead of moving the view there');
 is($dbh->selectrow_array('SELECT current_user'),'postgres','successful delegated ACL restoration returns to the original actor');
 my $first=snapshot();patch();is_deeply(snapshot(),$first,'already-current rerun is fully idempotent including relation/index OIDs and ACL');
 is($dbh->selectrow_array(q{SELECT current_setting('default_tablespace')}),'pg_global','idempotent rerun leaves the session setting unchanged');
 1;
};my $error=$@;$s->txn_rollback;$tx=0;ok($ok,'actual admin migration/ACL safety checks completed; all roles and DDL rolled back') or diag($error);
is($dbh->selectrow_array('SELECT count(*) FROM pg_roles WHERE rolname=ANY(?)',undef,[$role1,$role2]),0,'private test roles did not remain in the cluster');
done_testing;
