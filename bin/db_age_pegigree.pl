#!/usr/bin/perl

=head1 DESCRIPTION

The Perl script facilitates the creation of a pedigree graph database within Apache Age using data sourced from a PostgreSQL database. It establishes a connection to the PostgreSQL database, specifically querying for parent-child relationships within the database schema. The retrieved relationships, tagged with specific parent types ('female_parent' and 'male_parent'), are utilized to construct nodes and edges in the Apache Age graph database.

The script operates as follows:

    Database Connection: Connects to the PostgreSQL database using specified credentials (dbname, dbuser, dbpassword).
    Querying Relationships: Retrieves parent-child relationships from the PostgreSQL database using predefined SQL queries.
    Pedigree Graph Creation: Utilizes the retrieved data to create nodes representing parents and children within the Apache Age graph database.
    Graph Relationship Mapping: Establishes edges between parent and child nodes in the pedigree graph, representing the relationship type ('female_parent' or 'male_parent').

=cut

use strict;
use warnings;
use DBI;

# Database credentials
my $dbname = "XXXXX";
my $dbuser = "XXXXX";
my $dbpassword = "XXXXX";

# Establishing a connection to the PostgreSQL database
my $dbh = DBI->connect("DBI:Pg:dbname=$dbname;host=localhost;port=5432", $dbuser, $dbpassword) or die "Error $DBI::errstr";

# Setting the search path for the database
$dbh->do("SET search_path = ag_catalog, \"$dbuser\", public;");

# Querying the database for parent/child relationships
my $query = $dbh->prepare("
    SELECT stock_rel.subject_id as subject_stock_id, subject_val.uniquename as sub_name, stock_rel.object_id as object_stock_id, object_val.uniquename as obj_name, cvterm.name as parent_type
    FROM public.stock_relationship as stock_rel
        LEFT JOIN stock subject_val ON subject_val.stock_id = stock_rel.subject_id
        LEFT JOIN stock object_val ON object_val.stock_id = stock_rel.object_id
        LEFT JOIN cvterm ON cvterm.cvterm_id = stock_rel.type_id
    WHERE cvterm.name IN ('female_parent', 'male_parent')
    ORDER BY subject_val.stock_id, object_val.stock_id
    LIMIT 500
");

$query->execute;

# Processing the retrieved data
while (my ($subject_stock_id, $sub_name, $object_stock_id, $obj_name, $parent_type) = $query->fetchrow_array) {

    # Printing parent/child information
    print $subject_stock_id ."\t". $sub_name ."\t". $object_stock_id ."\t". $obj_name . "\t". $parent_type . "\n";

    # Creating child and parent nodes in the pedigree graph
    $dbh->do("
        SET search_path = ag_catalog, \"$dbuser\", public;
        SELECT * FROM ag_catalog.cypher('pedigree_graph', 
        \$\$ MERGE (:PEDIGREE{ name: '".$obj_name."',  
        stock_id: '".$object_stock_id."', 
        type: '' }) \$\$) 
        as (v ag_catalog.agtype)");

    $dbh->do("
        SET search_path = ag_catalog, \"\$user\", public;
        SELECT * FROM ag_catalog.cypher('pedigree_graph', 
        \$\$ MERGE (:PEDIGREE{ name: '".$sub_name."',  
        stock_id: '".$subject_stock_id."', 
        type: '' }) \$\$) 
        as (v ag_catalog.agtype)");

    $dbh->do("
        SET search_path = ag_catalog, \"$dbuser\", public;
        SELECT * FROM ag_catalog.cypher('pedigree_graph', \$\$ 
            MATCH (child:PEDIGREE {name: '".$obj_name."'})
            MATCH (parent:PEDIGREE {name: '".$sub_name."'})
            CREATE (parent)-[:IS_PARENT {relationship_type: '".$parent_type."'}]->(child)
            CREATE (child)-[:IS_CHILD {relationship_type: '".$parent_type."'}]->(parent)
        \$\$) as (v ag_catalog.agtype)");
}

# Closing the database connection
$query->finish;
$dbh->disconnect;