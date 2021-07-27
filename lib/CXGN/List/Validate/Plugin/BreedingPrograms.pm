
package CXGN::List::Validate::Plugin::BreedingPrograms;

use Moose;
use Data::Dumper;

sub name {
    return "breeding_programs";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

#    print STDERR "LIST: ".Data::Dumper::Dumper($list);
    my $breeding_program_cvterm_id  = SGN::Model::Cvterm->get_cvterm_row($schema, 'breeding_program','project_property')->cvterm_id();
    my @missing = ();
    foreach my $term (@$list) {

      my $rs = $schema->resultset('Project::Project')->search( { 'name' => $term, 'projectprops.type_id'=>$breeding_program_cvterm_id }, { join => 'projectprops' }  );
      if ($rs->count == 0) {
        push @missing, $term;
      }

    }
    return { missing => \@missing };

}

1;
