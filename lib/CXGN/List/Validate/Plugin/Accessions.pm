
package CXGN::List::Validate::Plugin::Accessions;

use Moose;

use Data::Dumper;
use SGN::Model::Cvterm;
#use Hash::Case::Preserve;

sub name {
    return "accessions";
}

sub validate {
    my $self = shift;
    my $schema = shift;
    my $list = shift;

#    tie my(%all_names), 'Hash::Case::Preserve';
    my $synonym_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'stock_synonym', 'stock_property')->cvterm_id();
    my $accession_type_id = SGN::Model::Cvterm->get_cvterm_row($schema, 'accession', 'stock_type')->cvterm_id();


    my @missing;
    my @wrong_case;
    my @multiple_wrong_case;
    my @synonyms;
    my @multiple_synonyms;

    # First filter out exact matches
    my $rs = $schema->resultset("Stock::Stock")->search({
        uniquename => {
            in => $list
        },
        'me.type_id' => $accession_type_id,
        is_obsolete => 'F'
    });
    my @exact = $rs->get_column('uniquename')->all();
    my %exact_map = map { $_=>1 } @exact;
    my @missing = grep { !exists $exact_map{$_} } @$list;


    # Now do more searches on the non-exact matches
    my %lc_missing_map = map { lc($_) => $_ } @missing;
    my @lc_missing_names = keys %lc_missing_map;
    # find case-insensitive matches
    my $case_rs = $schema->resultset("Stock::Stock")->search({
        'lower(uniquename)' => { 'in' => \@lc_missing_names },
        'me.type_id' => $accession_type_id,
        is_obsolete => 'F'
    });
    while (my $r=$case_rs->next) {
        my $uniquename = $r->uniquename();
        print STDERR "this is a case-independent match: $uniquename\n";
        push @wrong_case, [ $lc_missing_map{lc($uniquename)}, $uniquename ];
    }

    # find case-insensitive synonyms
    my $synonym_rs = $schema->resultset("Stock::Stock")->search(
        {
            'lower(stockprops.value)' => { 'in' => \@lc_missing_names },
            'stockprops.type_id' => $synonym_type_id,
        },
        {
            join => 'stockprops', '+select' => [ 'stockprops.value' ], '+as' => [ 'stockprops_value' ]
        }
    );
    while (my $r=$synonym_rs->next) {
        my $uniquename = $r->uniquename();
        print STDERR "this is a case-independent synonym match: $uniquename\n";
        push @synonyms, { item => $lc_missing_map{lc($uniquename)}, uniquename =>  $uniquename, synonym => $r->get_column('stockprops_value') };
    }

    # Now do more searches on the non-exact matches
    # foreach my $item (@missing) {
    #
    #     # # find case-insensitive matches
    #     # my $rs = $schema->resultset("Stock::Stock")->search({
    #     #     'lower(uniquename)' => lc($item),
    #     #     'me.type_id' => $accession_type_id,
    #     #     is_obsolete => 'F'
    #     # });
    #     #
    #     # if ($rs->count() == 1) {
    #     #     my $row = $rs->next();
    #     #     if ($row->uniquename() ne $item) {
    #     #         push @wrong_case, [ $item, $row->uniquename() ];
    #     #     }
    #     # }
    #     #
    #     # elsif ($rs->count() > 1) {
    #     #     while(my $row = $rs->next()) {
    #     #         push @multiple_wrong_case, [ $item, $row->uniquename() ];
    #     #     }
    #     # }
    #
    #     # find case-insensitive synonyms
    #     my $rs = $schema->resultset("Stock::Stock")->search(
    #         {
    #             'lower(stockprops.value)' => lc($item),
    #             'stockprops.type_id' => $synonym_type_id,
    #         },
    #         {
    #             join => 'stockprops', '+select' => [ 'stockprops.value' ], '+as' => [ 'stockprops_value' ]
    #         }
    #     );
    #
    #     if ($rs->count() == 1) {
    #         my $row = $rs->next();
    #         if ($row->uniquename() ne $item) { ## allow stocks to have the a synonym that is their own name - these synonyms should be removed from the dbs
    #             push @synonyms, { uniquename =>  $row->uniquename(), synonym => $row->get_column('stockprops_value') };
    #         }
    #     }
    #     elsif($rs->count() > 1)  {
    #         while (my $row = $rs->next()) {
    #             push @multiple_synonyms, [ $row->uniquename(), $row->get_column('stockprops_value') ];
    #         }
    #     }
    # }

    my $valid = 0;
    if ( (@multiple_synonyms ==0)  && (@synonyms == 0)  && (@wrong_case == 0) && (@missing == 0) && (@multiple_wrong_case ==0)) {
        $valid = 1;
    }

    return {
        exact => \@exact,
        missing => \@missing,
        wrong_case => \@wrong_case,
        multiple_wrong_case => \@multiple_wrong_case,
        synonyms => \@synonyms,
        multiple_synonyms => \@multiple_synonyms,
        valid => $valid,
    };
}

1;
