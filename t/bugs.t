#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use Test::More tests => 9;

use_ok( 'Text::WikiFormat' );

my $wikitext =<<WIKI;


	* unordered

Final paragraph.

WIKI

my $htmltext = eval { Text::WikiFormat::format($wikitext) };

is( $@, '',
	'format() should throw no warnings for text starting with newlines' );

like( $htmltext, qr!<li>unordered</li>!, 
	'ensure that lists followed by paragraphs are included correctly' ); 

package Baz;
use Text::WikiFormat as => 'wf';

::can_ok( 'Baz', 'wf' );

package main;

diag( 'make sure tag overrides work for Kake' );

$wikitext = <<WIKI;

* foo
** bar

WIKI

my %format_tags = (
	indent   => qr/^(?:\t+|\s{4,}|(?=\*+))/,
	blocks   => { unordered => qr/^\s*\*+\s*/ },
	nests    => { unordered => 1 },
);

$htmltext = Text::WikiFormat::format($wikitext, \%format_tags );

like( $htmltext, qr/<li>foo<\/li>/, "first level of unordered list" );
like( $htmltext, qr/<li>bar<\/li>/, "nested unordered lists OK" );

diag( 'Check that blocks not in blockorder are not fatal' );

%format_tags = (
	blocks     => {
		definition => qr/^:\s*/
	},
	definition => [ "<dl>\n", "</dl>\n", '<dt><dd>', "\n" ],
	blockorder => [ 'definition' ],
);

my $warning;
local $SIG{__WARN__} = sub { $warning = shift };
eval { Text::WikiFormat::format($wikitext, \%format_tags ) };
is( $@, '', 'format() should not die if a block is missing from blockorder' );
like( $warning, qr/No order specified/, '... warning instead' );

my $foo   = 'x';
$foo     .= '' unless $foo =~ /x/;
my $html  = Text::WikiFormat::format('test');
is( $html, "<p>test</p>\n", 'successful prior match should not whomp format()');
