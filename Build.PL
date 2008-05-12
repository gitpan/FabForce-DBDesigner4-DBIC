use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'FabForce::DBDesigner4::DBIC',
    license             => 'perl',
    dist_author         => 'Renee Baecker <module@renee-baecker.de>',
    dist_version_from   => 'lib/FabForce/DBDesigner4/DBIC.pm',
    requires            => {
        'FabForce::DBDesigner4' => 0.09,
        'File::Spec'            => 3.12,
    },
    build_requires => {
        'Test::More'            => 0,
        'Test::CheckManifest'   => 1.0,
        'Carp'                  => 0,
    },
    add_to_cleanup      => [ 'FabForce::DBDesigner4::DBIC-*' ],
);

$builder->create_build_script();
