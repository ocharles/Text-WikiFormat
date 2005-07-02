#! perl

use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
	license     => 'perl',
	module_name => 'Text::WikiFormat',
	requires    =>
	{
		'URI::Escape'  => '',
		'Scalar::Util' => '',
	},
	build_requires =>
	{
		'Test::More'   => 0.30,
	},
	create_makefile_pl => 'traditional',
	sign               => '1',
);

$build->create_build_script();
