
=head1 DESCRIPTION

A tiny mini script to display a group of traits/cvterms 
that start with a given letter

=head1 AUTHOR

Isaak Y Tecle (iyt2@cornell.edu)

=cut

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/blue_section_html
  info_section_html
  page_title_html
  columnar_table_html
  info_table_html
  /;

use CXGN::DB::Connection;
use CXGN::Chado::Cvterm;
use List::MoreUtils qw /uniq/;
use CXGN::Search::CannedForms;

my $page = CXGN::Page->new( "SGN QTL/Traits", "Isaak" );
$page->header();

#print page_title_html('SGN QTL Traits');
my $index = $page->get_arguments("index");

my $dbh       = CXGN::DB::Connection->new();
my $qtl_tools = CXGN::Phenome::Qtl::Tools->new();
my ( $all_traits, $all_trait_d ) = $qtl_tools->all_traits_with_qtl_data();
my @all_traits = @{$all_traits};
@all_traits = uniq(@all_traits);
@all_traits =
  sort { $a <=> $b } @all_traits;

my @index_traits;
foreach my $trait (@all_traits)
{
    if ( $trait =~ /^$index/i )
    {
        push @index_traits, $trait;

    }
}

my @traits_list;

if (@index_traits)
{
    foreach my $trait (@index_traits)
    {
        my $cvterm = CXGN::Chado::Cvterm::get_cvterm_by_name( $dbh, $trait );
        my $cvterm_id = $cvterm->get_cvterm_id();
        if ($cvterm_id)
        {
            push @traits_list,
              [
                map { $_ } (
qq |<a href=/chado/cvterm.pl?cvterm_id=$cvterm_id>$trait</a> |
                )
              ];
        }
        else
        {
            my $t = CXGN::Phenome::UserTrait->new_with_name( $dbh, $trait );
            my $trait_id = $t->get_user_trait_id();
            push @traits_list,
              [
                map { $_ } (
qq |<a href=/phenome/trait.pl?trait_id=$trait_id>$trait</a> |
                )
              ];

        }

    }

}

my $links = $qtl_tools->browse_traits();
print qq|<div style="margin: 0 auto; font-weight: bold">Browse traits with QTLs: $links</div>\n|;

print info_section_html (
                          title    => "Traits $index-",
                          contents => " ",
                        );

print columnar_table_html (
                            data          => \@traits_list,
                            __align       => 'l',
                            __alt_freq    => 2,
                            __alt_width   => 1,
                            __cellpadding => 20,
                          );

my $search = CXGN::Search::CannedForms::qtl_search_form();

print info_section_html (
                          title       => 'Search QTLs by trait names',
                          contents    => $search,
                          collapsible => 1,
                          collapsed   => 1,
                        );
$page->footer();

#############

