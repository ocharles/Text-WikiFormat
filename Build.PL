use Module::Build;
my $build = Module::Build->new(
	license     => 'perl',
	module_name => 'Text::WikiFormat',
	requires    => {
		'Test::More' => 0.30,
		URI::Escape  => '',
	},
);
$build->create_build_script;
