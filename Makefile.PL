use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Text::WikiFormat',
    'VERSION_FROM' => 'lib/Text/WikiFormat.pm', # finds $VERSION
    'PREREQ_PM' => { 'Test::More' => 0.30 },
    'PM'	=> { 'lib/Text/WikiFormat.pm' => '$(INST_LIBDIR)/WikiFormat.pm' },
);

