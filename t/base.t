#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '../lib', '../blib/lib';
}

use strict;

use Test::More tests => 26;

my $module = 'Text::WikiFormat';
use_ok( $module ) or exit;

can_ok( $module, 'start_block' );
my $text =<<END_WIKI;
= heading =

	* unordered item
	1. ordered item

	  some code

a normal paragraph

END_WIKI

sub fetchsub
{
	return $module->can( $_[0] );
}

my $tags = \%Text::WikiFormat::tags;
local *Text::WikiFormat::tags = $tags;

my $sb       = fetchsub( 'start_block' );
my ($result) = $sb->( '= heading =', $tags );

is_deeply( $result,
	{ type => 'header', args => [ '=', 'heading' ],
	  text => '', level => 0 },
		'start_block() should find headings' );

($result) = $sb->( '	* unordered item', $tags );
is_deeply( $result,
	{ type => 'unordered', args => [], text => 'unordered item', level => 2 },
		'... and unordered list' );

($result) = $sb->( '	6. ordered item', $tags );
is_deeply( $result,
	{ type => 'ordered', args => [ 6 ], text => 'ordered item', level => 2 },
		'... and ordered list' );

($result) = $sb->( '	  some code', $tags );
is_deeply( $result,
	{ type => 'code', args => [], text => "\tsome code", level => 0 },
		'... and code' );

($result) = $sb->( 'paragraph', $tags );
is_deeply( $result,
	{ type => 'paragraph', args => [], text => 'paragraph', level => 0 },
		'... and paragraph' );

can_ok( $module, 'merge_blocks' );
my $mb     = fetchsub( 'merge_blocks' );
my @result = $mb->(
	[{ type => 'code', text => 'a', level => 1 },
	 { type => 'code', text => 'b', level => 1 },
	], $tags
);
is( @result, 1, 'merge_blocks() should merge identical blocks together' );
is_deeply( $result[0]{text}, [qw( a b )], '... merging their text' );

@result = $mb->([
	{ type => 'unordered', text => 'foo', level => 1 },
	{ type => 'unordered', text => 'bar', level => 1 },
], $tags);
is( @result, 1,       '... merging unordered blocks' );
is_deeply( $result[0]{text}, [qw( foo bar)], '... and their text' );

@result = $mb->([
	{ type => 'ordered', text => 'foo', level => 2 },
	{ type => 'ordered', text => 'bar', level => 3 },
], $tags);
is( @result, 2, '... not merging blocks at different levels' );

can_ok( $module, 'process_blocks' );
my $pb  = fetchsub( 'process_blocks' );
@result = $pb->(
	[{ type => 'header',    text => [ '' ],                     level => 0,
	   args => [[ '==', 'my header' ]] },
	 { type => 'paragraph', text => [qw( my lines of text )],   level => 0 },
	 { type => 'ordered',   text => [qw( my ordered lines ),
	 { type => 'unordered', text => [qw( my unordered lines )], level => 2 },
	 ], level => 1, args => [[ 2 ], [ 3 ], [ 5 ]] },
	], $tags
);

is( @result, 1, 'process_blocks() should return processed text' );
$result = $result[0];
like( $result, qr!<h2>my header</h2>!,               '... marking header' );
like( $result, qr!<p>my<br />.+text</p>\n!s,  '...  paragraph' );
like( $result, qr!<li value="2">my</li>.+5">lines!s, '... ordered list' );
like( $result, qr!<ul>\n<li>my</li>!m,               '... and unordered list' );
like( $result, qr!</li>\n</ul>\n</li>\n</ol>!,       '... nesting properly' );

my $f          = fetchsub( 'format' );
my $fullresult = $f->(<<END_WIKI, $tags);
== my header ==

my
lines
of
text

	2. my
	3. ordered
	5. lines
		* my
		* unordered
		* lines
END_WIKI

is( $fullresult, $result, 'format() should give same results' );

$fullresult = $f->(<<END_WIKI, $tags);
= heading =

	* aliases can expire
		* use the Expires directive
		* no messages sent after the expiration date
	* aliases can be closed
		* use the Closed directive
		* messages allowed only from people on the list
	* aliases can auto-add people
		* use the Auto-add directive
		* anyone in the Cc line is added to the alias
		* they won't get duplicates
		* makes "just reply to alias" easier

END_WIKI

like( $fullresult, qr!expire<ul>!, 'nested list should start immediately' );
like( $fullresult, qr!date</li>\n</ul>!, '... ending after last nested item' );

can_ok( $module, 'check_blocks' );

my @warnings;
local $SIG{__WARN__} = sub {
	push @warnings, shift;
};

my $cb = \&Text::WikiFormat::check_blocks;
my $newtags = {
	blocks     => { foo => 1, bar => 1, baz => 1 },
	blockorder => [qw( bar baz )],
};
$cb->( $newtags );
my $warning = shift @warnings;
like( $warning, qr/No order specified for blocks 'foo'/,
	'check_blocks() should warn if block is not ordered' );

$newtags->{blockorder} = [ 'baz' ];
$cb->( $newtags );
$warning = shift @warnings;
ok( $warning =~ /foo/ && $warning =~ /bar/, '... for all missing blocks' )
	or diag( $warning );
