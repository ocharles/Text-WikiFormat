#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../lib';
	$INC{'Slash/Utility.pm'} = 1;
}

# for testing 'rootdir' in links
my %constants = (
	rootdir => 'rootdir',
);

local *Text::WikiFormat::getCurrentStatic;
*Text::WikiFormat::getCurrentStatic = sub {
	return \%constants;
};

use Test::More 'no_plan';

use_ok( 'Text::WikiFormat' );

my $wikitext =<<WIKI;
'''hello'''
''hi''
-----
woo
-----
LinkMeSomewhere
[LinkMeElsewhere|BYE]

	* unordered one
	* unordered two

	1. ordered one
	2. ordered two

	code one
	code two

WIKI

ok( %Text::WikiFormat::tags, 
	'%tags should be available from Text::WikiFormat');

my %tags = %Text::WikiFormat::tags;
my %opts = ( 
	prefix => 'rootdir/wiki.pl?page=',
);

my $htmltext = Text::WikiFormat::format_line($wikitext, \%tags, \%opts);

like( $htmltext, qr!\[<a href="rootdir/wiki\.pl\?page=LinkMeElsewhere">!, 
	'format_line () should link StudlyCaps where found)' );
like( $htmltext, qr!<strong>hello</strong>!, 'three ticks should mark strong');
like( $htmltext, qr!<em>hi</em>!, 'two ticks should mark emphasized' );
like( $htmltext, qr!<hr />\nwoo\n<hr />!m, 'four hyphens should make line' );
like( $htmltext, qr!LinkMeSomewhere</a>\n!m, 'should catch StudlyCaps' );
like( $htmltext, qr!\[!, 'should not handle extended links without flag' );

$opts{extended} = 1;
$htmltext = Text::WikiFormat::format_line($wikitext, \%tags, \%opts);
like( $htmltext, qr!^<a href="rootdir/wiki\.pl\?page=LinkMeElsewhere">!m,
	'should handle extended links with flag' );

my %lists = (
	first	=> [ qw( one two three ) ],
	second	=> [ qw( alpha beta gamma ) ],
	third	=> [ qw( gold silver bronze ) ],
);

my @tags = qw( aleph! !null !omega );

$htmltext = Text::WikiFormat::end_list(\%lists, 'third', \@tags);
like( $htmltext, qr!goldsilverbronze!, 'end_list() should use active list');
like( $htmltext, qr|^aleph!.+!null|, '... should use first/last provided tags');
is( scalar @{ $lists{third} }, 0, '... and should clear active list' );

$htmltext = Text::WikiFormat::format($wikitext);
like( $htmltext, qr!<strong>hello</strong>!, 'three ticks should mark strong');
like( $htmltext, qr!<em>hi</em>!, 'two ticks should mark emphasized' );

is( scalar @{ $tags{ordered} }, 3, 
	'... default ordered entry should have three items' );
is( ref( $tags{ordered}->[2] ), 'CODE', '... and should have subref' );

# make sure this starts a paragraph (buglet)
$htmltext = Text::WikiFormat::format("nothing to see here\nmoveAlong\n", {}, 
	{ prefix => 'foo=' });
like( $htmltext, qr!^<p>nothing!, '... should start new text with paragraph' );

# another buglet had the wrong tag pairs when ending a list
my $wikiexample =<<WIKIEXAMPLE;
I am modifying this because ItIsFun.  There is:
    1. MuchJoy
    2. MuchFun
    3. MuchToDo

Here is a paragraph.
There are newlines in my paragraph.

Here is another paragraph.

	here is some code that should have ''literal'' double single quotes
	how amusing

WIKIEXAMPLE

$htmltext = Text::WikiFormat::format($wikiexample, '', { prefix => 'foo=' });
like( $htmltext, qr!^<p>I am modifying this!, 
	'... should use correct tags when ending lists' );
like( $htmltext, qr!<p>Here is a paragraph.<br />!,
	'... should add no newline before paragraph, but at newline in paragraph ');
like( $htmltext, qr!<p>Here is another paragraph.</p>!,
	'... should add no newline at end of paragraph' );
like( $htmltext, qr|''literal'' double single|,
	'... should treat code sections literally' );

# test overridable tags

1;
