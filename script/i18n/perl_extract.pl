#!/usr/bin/env perl
# Parse source as data with PPI. Never require, do, eval, or execute that source.
use strict;
use warnings;
use utf8;
use JSON::PP;
use PPI;

local $/;
my $input = <STDIN>;
die "Extractor request exceeds limit\n" if !defined($input) || length($input) > 8 * 1024 * 1024;
my $request = decode_json($input);
die "Invalid extractor request\n" unless ref($request) eq 'HASH' && ref($request->{blocks}) eq 'ARRAY'
    && defined($request->{file}) && !ref($request->{file}) && @{$request->{blocks}} <= 2048;
my @records;

sub significant_children {
    my ($node) = @_;
    my @children = $node->schildren;
    while (@children == 1 && $children[0]->isa('PPI::Statement')) {
        @children = $children[0]->schildren;
    }
    return @children;
}

sub empty_list {
    my ($node) = @_;
    return $node && $node->isa('PPI::Structure::List') && !significant_children($node);
}

sub receiver_is_i18n {
    my ($word, $aliases) = @_;
    my $arrow = $word->sprevious_sibling;
    return 0 unless $arrow && $arrow->isa('PPI::Token::Operator') && $arrow->content eq '->';
    my $receiver = $arrow->sprevious_sibling;
    if ($receiver && $receiver->isa('PPI::Structure::List')) {
        my $method = $receiver->sprevious_sibling;
        my $operator = $method && $method->sprevious_sibling;
        my $class = $operator && $operator->sprevious_sibling;
        return 1 if $method && $method->isa('PPI::Token::Word') && $method->content eq 'new'
            && $operator && $operator->content eq '->' && $class && $class->isa('PPI::Token::Word')
            && $class->content eq 'SGN::I18N';
    }
    if (empty_list($receiver)) {
        $receiver = $receiver->sprevious_sibling;
    }
    return 1 if $receiver && $receiver->isa('PPI::Token::Word') && $receiver->content eq 'i18n';
    if ($receiver && $receiver->isa('PPI::Token::Symbol') && $aliases->{$receiver->content}) {
        die "Ambiguous or reassigned translator alias\n" if $aliases->{$receiver->content} eq 'ambiguous';
        return 1;
    }
    return 0;
}

sub known_receiver_chain {
    my ($word, $aliases) = @_;
    my $arrow = $word->sprevious_sibling;
    return 0 unless $arrow && $arrow->content eq '->';
    my $node = $arrow->sprevious_sibling;
    for (1 .. 32) {
        last unless $node;
        return 1 if $node->isa('PPI::Token::Word') && $node->content =~ /^(?:i18n|SGN::I18N)$/;
        return 1 if $node->isa('PPI::Token::Symbol') && $aliases->{$node->content};
        last if $node->isa('PPI::Token::Operator') && $node->content ne '->';
        $node = $node->sprevious_sibling;
    }
    return 0;
}

sub translator_aliases {
    my ($document) = @_;
    my %aliases;
    for my $statement (@{$document->find('PPI::Statement::Variable') || []}) {
        my @items = significant_children($statement);
        # Explicit Perl class annotations identify injected presentation
        # translators. The application boundary validates their runtime type;
        # extraction trusts this source contract, never executes it.
        if (@items >= 5 && $items[0]->content eq 'my'
            && $items[1]->isa('PPI::Token::Word') && $items[1]->content eq 'SGN::I18N'
            && $items[2]->isa('PPI::Token::Symbol') && $items[2]->content =~ /^\$/
            && $items[3]->content eq '=') {
            $aliases{$items[2]->content} = 1;
            next;
        }
        next unless @items >= 6 && $items[0]->content eq 'my'
            && $items[1]->isa('PPI::Token::Symbol') && $items[1]->content =~ /^\$/
            && $items[2]->content eq '=';
        pop @items if $items[-1]->content eq ';';
        if (@items == 7 && $items[3]->isa('PPI::Token::Word') && $items[3]->content eq 'SGN::I18N'
            && $items[4]->content eq '->' && $items[5]->isa('PPI::Token::Word') && $items[5]->content eq 'new'
            && $items[6]->isa('PPI::Structure::List')) {
            $aliases{$items[1]->content} = 1;
            next;
        }
        pop @items if empty_list($items[-1]);
        next unless $items[-1]->isa('PPI::Token::Word') && $items[-1]->content eq 'i18n'
            && $items[-2]->content eq '->';
        # Direct scalar/method chain only; reject expressions and unproven aliasing.
        my $valid = 1;
        for my $item (@items[3 .. $#items - 2]) {
            $valid = 0 unless $item->isa('PPI::Token::Symbol') || $item->isa('PPI::Token::Word')
                || ($item->isa('PPI::Token::Operator') && $item->content eq '->') || empty_list($item);
        }
        $aliases{$items[1]->content} = 1 if $valid;
    }
    # Do not infer the type of a reused/overwritten variable. Conservative
    # rejection is preferable to treating an unrelated widget's p() as i18n.
    my %writes;
    for my $statement (@{$document->find('PPI::Statement') || []}) {
        my @items = $statement->schildren;
        if (@items >= 3 && $items[0]->content eq 'my'
            && $items[1]->content eq 'SGN::I18N' && $items[2]->isa('PPI::Token::Symbol')) {
            $writes{$items[2]->content}++;
        } elsif (@items >= 2 && $items[0]->content =~ /^(?:my|our|local)$/ && $items[1]->isa('PPI::Token::Symbol')) {
            $writes{$items[1]->content}++;
        } elsif (@items >= 2 && $items[0]->isa('PPI::Token::Symbol') && $items[1]->isa('PPI::Token::Operator')
                 && $items[1]->content =~ /^(?:=|\.=|\+=|-=|\|\|=|&&=|\/\/=)$/) {
            $writes{$items[0]->content}++;
        }
    }
    for my $name (keys %aliases) {
        $aliases{$name} = 'ambiguous' if ($writes{$name} || 0) > 1;
    }
    return \%aliases;
}

sub literal {
    my ($tokens, $where) = @_;
    die "$where: marked source argument must be one constant quoted literal\n" unless @$tokens == 1;
    my $token = $tokens->[0];
    return $token->literal if $token->isa('PPI::Token::Quote::Single');
    die "$where: marked source uses an unsupported or interpolated literal\n"
        unless $token->isa('PPI::Token::Quote::Double') && !$token->interpolations;
    my $raw = $token->string;
    my %escapes = ('n'=>"\n", 'r'=>"\r", 't'=>"\t", 'b'=>"\b", 'f'=>"\f",
                   '\\'=>'\\', '"'=>'"', '$'=>'$', '@'=>'@');
    my $result = '';
    for (my $i = 0; $i < length($raw); $i++) {
        my $character = substr($raw, $i, 1);
        if ($character eq '\\') {
            my $next = substr($raw, ++$i, 1);
            die "$where: unsupported marked literal escape\n" unless exists($escapes{$next});
            $result .= $escapes{$next};
        } else {
            $result .= $character;
        }
    }
    return $result;
}

my @parsed_blocks;
my %batch_aliases;
for my $block (@{$request->{blocks}}) {
    die "Invalid source block\n" unless ref($block) eq 'HASH' && defined($block->{source}) && !ref($block->{source})
        && length($block->{source}) <= 2 * 1024 * 1024 && defined($block->{line_offset})
        && $block->{line_offset} =~ /^\d+$/;
    my $source = $block->{source};
    my $document = PPI::Document->new(\$source);
    die "PPI could not parse the source block\n" unless $document;
    # Native Perl accepts a final module true expression without a semicolon.
    # Normalize only that parser input; source bytes and existing line numbers
    # stay unchanged. Any other lexical/structural damage still fails closed.
    if (!$block->{fragment} && !$document->complete
        && $request->{file} =~ /\.pm\z/ && $source =~ /(?:\A|\n)1\s*\z/) {
        my $terminated = $source . "\n;\n";
        $document = PPI::Document->new(\$terminated);
    }
    die "PPI source block is incomplete\n" unless $block->{fragment} || ($document && $document->complete);
    die "PPI found unknown source tokens\n" if $document->find('PPI::Token::Unknown');
    # PPI 1.291 marks unterminated heredocs in tokenizer metadata; Document's
    # structural complete() alone does not report that lexical damage.
    die "PPI found damaged lexical tokens\n" if $document->find(sub {
        $_[1]->isa('PPI::Token') && $_[1]->{_damaged}
    });
    my $aliases = translator_aliases($document);
    $batch_aliases{$_} = 1 for keys %$aliases;
    push @parsed_blocks, {block=>$block, document=>$document, aliases=>$aliases};
}

for my $parsed (@parsed_blocks) {
    my ($block, $document, $aliases) = @{$parsed}{qw(block document aliases)};
    my $calls = $document->find(sub { $_[1]->isa('PPI::Token::Word') && $_[1]->content =~ /^(?:p|np|SGN::I18N::translate)$/ }) || [];
    for my $word (@$calls) {
        my $line = $word->location->[0] + $block->{line_offset};
        my $where = "$request->{file}:$line";
        my $helper = $word->content eq 'SGN::I18N::translate';
        if (!$helper && !receiver_is_i18n($word, $aliases)) {
            die "$where: unsupported known i18n receiver chain\n" if known_receiver_chain($word, $aliases);
            # Mason init/shared/once/def/method fragments are not one proven
            # lexical program. Never transfer their alias types by name alone,
            # and never silently omit a use of a known name in another block.
            die "$where: unsupported cross-fragment translator alias\n" if known_receiver_chain($word, \%batch_aliases);
            next;
        }
        my $list = $word->snext_sibling;
        die "$where: marked call requires an argument list\n" unless $list && $list->isa('PPI::Structure::List');
        my @arguments = ([]);
        for my $token (significant_children($list)) {
            if ($token->isa('PPI::Token::Operator') && $token->content eq ',') {
                push @arguments, [];
            } else {
                push @{$arguments[-1]}, $token;
            }
        }
        my $plural;
        if ($helper) {
            next if @arguments == 1; # Guarded translator acquisition, no message.
            die "$where: invalid translation helper arguments\n" if @arguments < 3 || @arguments > 5;
            shift @arguments; # Explicit translator/provider is not a literal.
            if (@arguments == 4) {
                my $options = $arguments[3];
                die "$where: helper options must be a literal hash\n"
                    unless @$options == 1 && $options->[0]->isa('PPI::Structure::Constructor')
                    && $options->[0]->start->content eq '{';
                my @items = significant_children($options->[0]);
                for (my $i = 0; $i < @items; $i++) {
                    next unless $items[$i]->isa('PPI::Token::Word') && $items[$i]->content eq 'plural';
                    die "$where: helper plural must be a literal pair\n"
                        unless $items[$i+1] && $items[$i+1]->content eq '=>'
                        && $items[$i+2] && $items[$i+2]->isa('PPI::Structure::Constructor')
                        && $items[$i+2]->start->content eq '[';
                    my @pair = significant_children($items[$i+2]);
                    die "$where: helper plural needs source and count\n" unless @pair >= 3 && $pair[1]->content eq ',';
                    $plural = literal([$pair[0]], $where);
                }
            }
        }
        my $required = $word->content eq 'np' ? 3 : 2;
        die "$where: not enough marked source arguments\n" if @arguments < $required;
        my @values = map { literal($arguments[$_], $where) } 0 .. $required - 1;
        $plural = $values[2] if $required == 3;
        die "$where: invalid message source or context separator\n" if !length($values[1]) || ($required == 3 && !length($values[2]))
            || grep { /[\x00\x04]/ } @values;
        push @records, {context=>$values[0], source=>$values[1], plural=>$plural,
                        reference=>$where};
    }
}
print encode_json({schema=>3,parser=>'PPI',parserVersion=>$PPI::VERSION,records=>\@records});
