#!/usr/bin/perl -w

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib';
}

use strict;
use Test::More tests => 8;

use_ok( 'Text::WikiFormat' );
ok( exists $Text::WikiFormat::tags{ listorder },
	'TWF should have a listorder entry in %tags' );

# isan ARRAY
isa_ok( $Text::WikiFormat::tags{ listorder }, 'ARRAY', '... and we hope it' );

like( join(' ', @{ $Text::WikiFormat::tags{ listorder } }),
	qr/ordered.+ordered.+code/,
	'... and code should come after ordered and unordered' );

can_ok( 'Text::WikiFormat', '_available_lists' );
my %lists = (
	lists => {
		foo => qr//,
		bar => qr//,
		baz => qr//,
	},
	listorder => [qw( foo baz )],
);

my $lists = Text::WikiFormat::_available_lists( \%lists );
is( ref $lists, 'ARRAY', '_available_lists() should return an array ref' );
is( @$lists, 3, '... with an entry for each list type' );
is( join(' ', @$lists), 'bar foo baz', '... with new types at the start' );
